# miyoo-fetch

fetch rom for the miyoo-mini

## usage

```
git/miyoo-fetch [main●] » ./miyoo-fetch
Welcome ! Please enter the rom ID from edgeemu.net:
236252
info: Requesting rom's info...
info: Looking for ROM's name
info: Rom's id: 236252 !
info: Rom's name: Pokemon - Crystal Version (USA, Europe) (Rev A) !
info: Opened destination file
info: Requesting download...
info: Downloading...
info: Downloaded !
```

## how to compile
`zig build-exe -O ReleaseSafe --target arm-linux miyoo-fetch.zig`

## Issue

It seems there is an issue currently with `http.Client`, which make an error `TlsInitializationFailed`, when being run on the Miyoo Mini +.
