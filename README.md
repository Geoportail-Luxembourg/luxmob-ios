# iOS LuxMob


## Installation

git clone --recursive git@github.com:Geoportail-Luxembourg/luxmob-ios.git


## Develop with XCode

open luxmob-ios/LuxMob.xcodeproj in XCode
run in a simulator or real device by clicking on the triangle at the top left of the title bar


## Debug iOS part

You can set breakpoints or add print statements.


## Debug browser part

You can inspect the webview using Safari: Develop -> name of the device -> LuxMob/offline-demo.geoportail.lu - main


## SSL certificate

The embedded HTTPS server uses a custom CA and locally generated certificate.
If you need to renew the certificate (from Tools directory of the Telegraph project):

cd catools
./certs.sh
cp p12/localhost.p12  geoportail.lu/localhost.p12

