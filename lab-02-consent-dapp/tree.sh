#!/usr/bin/env bash
# Prints the project layout used in Chapter 4 (build output and dependencies omitted).
find contracts/contracts contracts/test contracts/ignition contracts/scripts \
     frontend/src frontend/test frontend/index.html frontend/.env.example \
     contracts/hardhat.config.ts frontend/vite.config.ts -type f | sort
