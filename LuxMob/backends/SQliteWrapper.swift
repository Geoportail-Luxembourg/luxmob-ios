// See https://www.raywenderlich.com/385-sqlite-with-swift-tutorial-getting-started

import SQLite3
import Foundation


enum SQLiteError: Error {
    case OpenDatabase(message: String)
    case Prepare(message: String)
    case Step(message: String)
    case Bind(message: String)
}

class SQLiteDatabase {
  fileprivate let dbPointer: OpaquePointer?
    var insertStatement: OpaquePointer? = nil
    var selectStatement: OpaquePointer? = nil
    var updateStatement: OpaquePointer? = nil
    var clearStatement: OpaquePointer? = nil
    var removeStatement: OpaquePointer? = nil

  fileprivate init(dbPointer: OpaquePointer?) {
    self.dbPointer = dbPointer
  }

  deinit {
    sqlite3_close(dbPointer)
  }


    static func open(path: String) throws -> SQLiteDatabase {
      var db: OpaquePointer? = nil
        var dbWrapper: SQLiteDatabase? = nil
        print(sqlite3_threadsafe())
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK {
            print("success")
        let db = SQLiteDatabase(dbPointer: db)
        try? db.createTable()
        try! db.prepareStatements()
        return db
      } else {
        defer {
            if dbWrapper != nil {
                dbWrapper!.destroyPreparedStatements()
            }
          if db != nil {
            sqlite3_close(db)
          }
        }

        if let errorPointer = sqlite3_errmsg(db) {
          let message = String.init(cString: errorPointer)
          throw SQLiteError.OpenDatabase(message: message)
        } else {
          throw SQLiteError.OpenDatabase(message: "No error message provided from sqlite.")
        }
      }
    }


    fileprivate var errorMessage: String {
      if let errorPointer = sqlite3_errmsg(dbPointer) {
        let errorMessage = String(cString: errorPointer)
        return errorMessage
      } else {
        return "No error message provided from sqlite."
      }
    }

    func prepareStatements() throws {
        let insertSql = "INSERT INTO Offline (key, value) VALUES (?, ?);"
        self.insertStatement = try prepareStatement(sql: insertSql)
        
        let selectSql = "SELECT value FROM Offline WHERE key = ?;"
        self.selectStatement = try prepareStatement(sql: selectSql)

        let updateSql = "UPDATE Offline SET value=? WHERE key = ?;"
        self.updateStatement = try prepareStatement(sql: updateSql)
        
        let clearSql = "DELETE FROM Offline;"
        self.clearStatement = try prepareStatement(sql: clearSql)

        let removeSql = "DELETE FROM Offline WHERE key = ?;"
        self.removeStatement = try prepareStatement(sql: removeSql)
    }
    
    func destroyPreparedStatements() {
        if self.insertStatement != nil {
            sqlite3_finalize(self.insertStatement)
        }
        if self.updateStatement != nil {
            sqlite3_finalize(self.updateStatement)
        }
        if self.selectStatement != nil {
            sqlite3_finalize(self.selectStatement)
        }
        if self.removeStatement != nil {
            sqlite3_finalize(self.removeStatement)
        }
        if self.clearStatement != nil {
            sqlite3_finalize(self.clearStatement)
        }
    }

  func prepareStatement(sql: String) throws -> OpaquePointer? {
    var statement: OpaquePointer? = nil
    guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
      throw SQLiteError.Prepare(message: errorMessage)
    }

    return statement
  }

  func createTable() throws {
    let sql = "CREATE TABLE offline (key TEXT PRIMARY KEY, value TEXT)"
    let createTableStatement = try prepareStatement(sql: sql)

    defer {
      sqlite3_finalize(createTableStatement)
    }

    guard sqlite3_step(createTableStatement) == SQLITE_DONE else {
      throw SQLiteError.Step(message: errorMessage)
    }
    print("table created.")
  }

func insertItem(key: String, value: String) throws {
    let insertSql = "INSERT INTO Offline (key, value) VALUES (?, ?);"
    let insertStatement = try prepareStatement(sql: insertSql)
    
    defer {
        sqlite3_finalize(insertStatement)
    }
    guard sqlite3_bind_text(insertStatement, 1, key, -1, nil) == SQLITE_OK  &&
        sqlite3_bind_text(insertStatement, 2, value, -1, nil) == SQLITE_OK else {
            throw SQLiteError.Bind(message: errorMessage)
    }
    
    guard sqlite3_step(insertStatement) == SQLITE_DONE else {
        throw SQLiteError.Step(message: errorMessage)
    }
}
    
    func updateItem(key: String, value: String) throws {
        let updateSql = "UPDATE Offline SET value=? WHERE key = ?;"
        let updateStatement = try prepareStatement(sql: updateSql)
        defer {
            sqlite3_finalize(updateStatement)
        }
        guard sqlite3_bind_text(updateStatement, 2, key, -1, nil) == SQLITE_OK  &&
            sqlite3_bind_text(updateStatement, 1, value, -1, nil) == SQLITE_OK else {
                throw SQLiteError.Bind(message: errorMessage)
        }
        
        guard sqlite3_step(updateStatement) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
    
func setItem(key: String, value: String) throws {
    do {
        try self.insertItem(key: key, value: value)
        print("Successfully inserted row.")
    } catch {
        try self.updateItem(key: key, value: value)
        print("Successfully updated row.")
    }
  }

  func getItem(key: String) -> String? {
    sqlite3_reset(self.selectStatement)

    guard sqlite3_bind_text(self.selectStatement, 1, key, -1, nil) == SQLITE_OK else {
      return nil
    }

    guard sqlite3_step(self.selectStatement) == SQLITE_ROW else {
      return nil
    }

    let queryResultCol1 = sqlite3_column_text(self.selectStatement, 1)
    if queryResultCol1 != nil {
        return String(cString: queryResultCol1!)
    }
    return nil
  }

    
  func clear() {
    guard sqlite3_step(self.clearStatement) == SQLITE_ROW else {
      return
    }
  }

    
  func removeItem(key: String) {
    sqlite3_reset(self.removeStatement)
    guard sqlite3_bind_text(self.removeStatement, 1, key, -1, nil) == SQLITE_OK else {
      return
    }

    guard sqlite3_step(self.removeStatement) == SQLITE_ROW else {
      return
    }
  }
}
