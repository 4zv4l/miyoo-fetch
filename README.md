# miyoo-fetch

Fetch game file for the miyoo-mini plus

## usage

```
git/miyoo-fetch [main●] » ./miyoo-fetch
Welcome !
Please enter the rom ID from edgeemu.net: 11111
info: filename: Tunnel Runner.7z
info: Downloading 877kb
info: Downloaded 877/877kb
info: Thanks for using me :)
```

## how to compile
`zig build-exe -O ReleaseFast --target arm-linux miyoo-fetch.zig`

## Issue

It seems there is an issue currently with `http.Client`, which make an error `TlsInitializationFailed`, when being run on the Miyoo Mini +.

* Apparently it could be due to the TlS 1.3 not being supported on the Miyoo

## Disclaimer

This code was made for learning purpose only, I am not responsible for the usage of it.

You can find some nice abandonware on [myabandonware.com](https://www.myabandonware.com).
