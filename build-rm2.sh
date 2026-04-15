#!/bin/bash
rm -rf rmd
mkdir -p rmd/backend
cp manifest.json rmd
cp icon.png rmd
rcc --binary -o rmd/resources.rcc application.qrc
GOOS=linux GOARCH=arm GOARM=7 go build .
cp remarkdown rmd/backend/entry
