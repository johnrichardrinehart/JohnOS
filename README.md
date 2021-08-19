# Project Description
The goal of this project is to design an ephemeral operating system that can be
executed from externally-attached storage (flash drive, primarily) and
optionally be loaded into RAM at boot-time so that external storage can be
disconnected after boot has completed.

# Outstanding Deficiencies
- [ ] `emacs` configuration
- [ ] secrets management (U2F)
- [ ] `systemd-homed` support
- [ ] encrypted persistent storage
- [ ] `git push` checks before shutdown
- [x] networking
- [x] sound
- [ ] bluetooth
- [ ] smart screen-attachment detection (attach external monitor and extend output automagically)
- [x] smart keyboard-layout detection (dvorak from built-in laptop keyboard, US from attached USB-C keyboard)
- [ ] cloud back-up feature (back-up before shutdown)
