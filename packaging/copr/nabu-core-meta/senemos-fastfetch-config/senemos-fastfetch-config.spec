Name:           senemos-fastfetch-config
Version:        1.1.0
Release:        1%{?dist}
Summary:        Locale-aware Fastfetch configuration for SENEMOS
License:        MIT
URL:            https://github.com/MCC45TR/Nabu-Fedora-Rawhide-Builder
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
BuildRequires:  python3
Requires:       bash
Requires:       fastfetch
Conflicts:      nabu-core-meta < 3.0.0-56

%description
SENEMOS Fastfetch configuration with locale-aware labels for every language
shipped by MFile Finder. The senemos-fastfetch launcher normalizes regional
locale names and falls back to English for unsupported locales.

The package deliberately does not replace Fedora's /usr/bin/fastfetch. It owns
the optional system-wide fallback configuration and a shell integration file,
so both are removed cleanly when the package is uninstalled.

%prep
%autosetup

%build

%install
install -Dm0755 bin/senemos-fastfetch \
    %{buildroot}%{_bindir}/senemos-fastfetch
install -Dm0644 profile.d/senemos-fastfetch.sh \
    %{buildroot}%{_sysconfdir}/profile.d/senemos-fastfetch.sh
install -d %{buildroot}%{_sysconfdir}/xdg/fastfetch
ln -s ../../../usr/share/senemos-fastfetch-config/i18n/en.jsonc \
    %{buildroot}%{_sysconfdir}/xdg/fastfetch/config.jsonc
install -Dm0644 man/senemos-fastfetch.1 \
    %{buildroot}%{_mandir}/man1/senemos-fastfetch.1
install -d %{buildroot}%{_datadir}/senemos-fastfetch-config/i18n
install -m0644 i18n/*.jsonc \
    %{buildroot}%{_datadir}/senemos-fastfetch-config/i18n/

%check
bash -n bin/senemos-fastfetch
bash -n profile.d/senemos-fastfetch.sh
test "$(readlink %{buildroot}%{_sysconfdir}/xdg/fastfetch/config.jsonc)" = \
    "../../../usr/share/senemos-fastfetch-config/i18n/en.jsonc"
python3 - <<'PY'
import json
from pathlib import Path

configs = sorted(Path("i18n").glob("*.jsonc"))
assert len(configs) == 27, f"expected 27 locale configs, found {len(configs)}"
assert {path.stem for path in configs} == {
    "ar", "az", "bn", "cs", "de", "el", "en", "es", "fa", "fi", "fr",
    "hi", "hy", "id", "it", "ja", "ko", "nl", "pl", "pt", "ro", "ru",
    "sv", "tr", "uk", "ur", "zh",
}
for config in configs:
    data = json.loads(config.read_text(encoding="utf-8"))
    assert len(data["modules"]) == 16, config
PY

%files
%license LICENSE
%doc README.md
%{_bindir}/senemos-fastfetch
%{_sysconfdir}/profile.d/senemos-fastfetch.sh
%{_sysconfdir}/xdg/fastfetch/config.jsonc
%{_mandir}/man1/senemos-fastfetch.1*
%{_datadir}/senemos-fastfetch-config/

%changelog
* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 1.1.0-1
- Route interactive fastfetch calls through the locale-aware launcher.
- Own the system Fastfetch fallback configuration for clean removal.
- Coordinate file ownership migration from nabu-core-meta 3.0.0-56.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 1.0.0-1
- Add locale-aware Fastfetch configuration for all 27 MFile Finder languages.
- Normalize regional locale names and provide an English fallback.
