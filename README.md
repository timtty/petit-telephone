# petit_telephone

Minimal on-site PBX: [Yate](https://yate.ro) in Docker, for a handful of
SIP softphones on the local network. Phones register with an extension
and password, and can call each other. There is no outside line.

- **Extensions:** each section in `regfile.conf` is a SIP account and
  also the number other phones dial to reach it: 100 (Main), 555 (TT)
  and 888 (CC). Passwords live in the gitignored `conf/regfile.conf`;
  a short shared one keeps handset setup quick, which is only sensible
  while the PBX stays on a closed LAN.
- **Echo test:** dial 600 to hear your own voice played back, which
  checks the mic, speaker and media path.
- **Text messages:** handsets with SIP messaging (SIP `MESSAGE`, e.g.
  the Grandstream WP826) can text each other by extension number.
- **Auth:** every REGISTER, INVITE and MESSAGE is challenged with digest auth
  against `regfile.conf`, so unknown devices can't place calls.

## Usage

1. `cp conf/regfile.conf.sample conf/regfile.conf` and set the
   passwords (and adjust the extensions if needed).
2. `docker compose up -d --build` (the first build compiles Yate and
   takes a few minutes).
3. Configure each softphone:
   - user / auth user: the extension, e.g. `555`
   - password: from `conf/regfile.conf`
   - domain / registrar: the server's LAN IP, UDP port 5060
   - codecs: G.711 µ-law / A-law
4. Watch with `docker compose logs -f`. Each phone shows up as
   `Registered user '555'`.

Admin console: run `nc 127.0.0.1 5038` on the server itself (it's
loopback-only; try `status`, `status sip`, `help`).

## Layout

- `conf/` is mounted at `/etc/yate` (read-only):
  - `yate.conf` loads only the 7 modules the PBX uses
  - `regfile.conf` holds the extensions and their passwords (not in git)
  - `regexroute.conf` demands auth on calls, routes 600 to echo, and
    hands text messages to regfile
  - `ysipchan.conf` also enables SIP MESSAGE (`[message]`)
  - `ysipchan.conf` is the SIP listener on UDP 0.0.0.0:5060
  - `yrtpchan.conf` sets the RTP port range to 20000–20100

## Networking

The container uses `network_mode: host`. SIP carries the PBX's own
address in Contact/Via/SDP, so Yate has to see the real LAN IP; behind
Docker's port-mapping NAT it would advertise a 172.x address that phones
can't reach. This assumes a Linux server. Docker Desktop on macOS or
Windows doesn't give containers the host's LAN interface.

Open in the host firewall (LAN only): `5060/udp` and `20000-20100/udp`.

All audio is relayed through the PBX. That covers codec mismatches, and
softphones behind NAT work too, because `autoaddr` latches onto the
address the phone's media actually comes from.

Registrations are kept only in memory. After a restart, a phone can't be
reached until it re-registers, which takes at most 5 minutes
(`expires_max=300`).

## Text messages

A MESSAGE is authenticated like a call, then regfile looks up where the
recipient is registered and the PBX relays the text there. The relayed
message comes *from* the sender's authenticated extension, so the
recipient can reply. Two `regexroute.conf` parameters make this work:

- `osip-prefix=osip_` stops Yate from copying the sender's own SIP
  headers (From, To, Contact, ...) into the relayed message as
  duplicates, which handsets silently drop.
- `user=${username}` sets the relayed From to the sender's extension
  instead of the bare PBX address.

There is no store-and-forward. A message to an extension that isn't
registered fails back to the sender. Once a message has been handed to
the recipient's handset, the PBX confirms it to the sender without
waiting for the handset's own reply.

## Finding the PBX

With DHCP the PBX's address can change. The companion project
`rpi_findme_ble` broadcasts the Pi's current address
over Bluetooth LE; with `FINDME_NAME=PBX` it shows up in any BLE scanner
app as `PBX 192.168.1.194`.

## Local test (no real phones needed)

`test/` contains a phone simulator: a second Yate container that
registers as extensions 555 and 888 (from `test/regfile.test.conf`)
and answers any call with the echo script. The overlay moves the PBX
onto the compose network so the two containers can reach each other.

```sh
docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --build
./test/call.sh 888    # 555 -> 888; also try 600 (echo)
./test/message.sh 888 # text 555 -> 888
```

`message.sh` prints the message as the simulated 888 received it:
`MESSAGE from 555 to 888: hello from 555`.

`call.sh` places the call with a 1 kHz tone as the voice, holds it for
6 s, prints `status sip`, then hangs up. A successful call shows both
SIP legs as `answered`, and the PBX log shows:

```
<sip/1:MILD> Call rejected error='noauth'      # first INVITE challenged (401)
<regfile:INFO> Routed '888' via 'sip/sip:888@…' # retried with credentials
<yrtp:INFO> RTP starting format 'mulaw'
```

Tear down with the same `-f` pair and `down`.

## Roadmap

- **Phase 2 — outside line:** register to a SIP trunk via
  `accfile.conf` (as in petite_fax), route `^9\(.*\)$` out through it
  with `line/\1;line=trunk`, and send inbound DID calls to 100.
- **Phase 3 — voicemail / call log:** enable `cdrbuild` + `cdrfile` for
  a CDR log, plus a voicemail script for unanswered calls.

## License

MIT, see `LICENSE`. Yate itself is GPL-licensed and is fetched and
built by the Dockerfile, not included here.
