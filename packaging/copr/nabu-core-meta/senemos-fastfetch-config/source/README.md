# SENEMOS Fastfetch configuration

Interactive shells route `fastfetch` through `senemos-fastfetch`, which selects
a translated configuration from the current message locale. The explicit
`senemos-fastfetch` command remains available. Set `FASTFETCH_LOCALE` to
override selection:

```sh
FASTFETCH_LOCALE=tr_TR senemos-fastfetch
FASTFETCH_LOCALE=zh_CN senemos-fastfetch
```

Regional locale names map to their base language. Unsupported locales and the
`C`/`POSIX` locales fall back to English.

The package does not replace Fedora's `/usr/bin/fastfetch`. Shell integration
in `/etc/profile.d` performs the interactive redirection, while the system
configuration path provides an English fallback for direct binary execution.
Both files are owned and removed by this package.
