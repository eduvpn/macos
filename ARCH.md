# Architecture

This is a brief overview of the client architecture of the eduVPN application
for MacOS.

![Architecture](img/ARCH.png)

## launchd

The helper is started on demand via launchd.

## eduVPN app

The eduVPN GUI in which the user can add eduVPN/LC providers, choose VPN
profiles to connect with, and view connection stats and the OpenVPN log.
It also provides the eduVPN helper with OpenVPN configurations.

## eduVPN helper

Starts OpenVPN process with given configuration, sets up a leasewatch daemon.

## OpenVPN

The executed OpenVPN binary which sets up the routes and establishes the VPN
connection with the eduVPN server.

## client.{up/down}.eduvpn.sh

The scripts given as arguments (--up,--down) to the OpenVPN process. These
setup and restore the DNS settings.

## leasewatch daemon (and leasewatch.sh)

The leasewatch daemon watches the current DNS settings by executing
leasewatch.sh. This script will restore any changed DNS settings while a VPN
connection is active.

## VPN Connection

The active VPN connection with an eduVPN server.

