// SPDX-License-Identifier: MIT
#include <QApplication>
#include <QInputDialog>
#include <QMessageBox>
#include <QProcess>
#include <QTextStream>
#include <iterator>

namespace {
struct Choice {
    const char *id;
    const char *panel;
    const char *profile;
    const char *label;
};

constexpr Choice choices[] = {
    {"36-02-0b-srgb", "36-02-0b", "srgb", "36-02-0b — Android HAL sRGB"},
    {"36-02-0b-display-p3", "36-02-0b", "display-p3", "36-02-0b — Android HAL Display P3"},
    {"42-02-0a-srgb", "42-02-0a", "srgb", "42-02-0a — Android HAL sRGB"},
    {"42-02-0a-display-p3", "42-02-0a", "display-p3", "42-02-0a — Android HAL Display P3"},
};

const Choice *findChoice(const QString &id) {
    for (const auto &choice : choices) {
        if (id == QLatin1StringView(choice.id)) return &choice;
    }
    return nullptr;
}

struct Result {
    int status;
    QString output;
};

Result apply(const Choice &choice, bool dryRun) {
    const QString tool = qEnvironmentVariable("SENEMOS_NABU_PROFILE_TOOL", "/usr/bin/senemos-nabu-color-profile");
    const QString directory = qEnvironmentVariable("SENEMOS_NABU_PROFILE_DIR", "/usr/share/color/icc/senemos/nabu");
    QStringList arguments{"apply", QLatin1StringView(choice.profile), "--panel",
                          QLatin1StringView(choice.panel), "--profile-dir", directory};
    if (dryRun) arguments << "--dry-run";

    QProcess process;
    process.setProcessChannelMode(QProcess::MergedChannels);
    process.start(tool, arguments, QIODevice::ReadOnly);
    if (!process.waitForStarted(3000))
        return {1, QStringLiteral("Could not start color-profile helper: %1").arg(process.errorString())};
    // The native profile tool can spend up to 10 s discovering KScreen and
    // 15 s applying the chosen ICC profile; leave room for process startup.
    if (!process.waitForFinished(35000)) {
        process.kill();
        process.waitForFinished(1000);
        return {124, QStringLiteral("Color-profile helper timed out")};
    }
    const QString output = QString::fromUtf8(process.readAll()).trimmed();
    if (process.exitStatus() != QProcess::NormalExit)
        return {1, output.isEmpty() ? QStringLiteral("Color-profile helper crashed") : output};
    return {process.exitCode(), output};
}
}

int main(int argc, char **argv) {
    // QCoreApplication::arguments() requires an application instance; parse
    // argv directly so --list and --apply need no graphical session.
    QStringList cli;
    for (int i = 1; i < argc; ++i) cli << QString::fromLocal8Bit(argv[i]);

    if (!cli.isEmpty()) {
        const QString command = cli.takeFirst();
        if (command == "--help" || command == "-h") {
            QTextStream(stdout) << "Usage: senemos-nabu-color-settings [--list | --apply PROFILE [--dry-run]]\n";
            return 0;
        }
        if (command == "--list" && cli.isEmpty()) {
            for (const auto &choice : choices)
                QTextStream(stdout) << choice.id << '\t' << choice.panel << '\t' << choice.label << '\n';
            return 0;
        }
        if (command == "--apply" && (cli.size() == 1 || (cli.size() == 2 && cli[1] == "--dry-run"))) {
            const Choice *choice = findChoice(cli[0]);
            if (!choice) {
                QTextStream(stderr) << "Unknown Nabu color profile: " << cli[0] << '\n';
                return 2;
            }
            const Result result = apply(*choice, cli.size() == 2);
            if (!result.output.isEmpty()) {
                QTextStream stream(result.status == 0 ? stdout : stderr);
                stream << result.output << '\n';
            }
            return result.status;
        }
        QTextStream(stderr) << "Usage: senemos-nabu-color-settings [--list | --apply PROFILE [--dry-run]]\n";
        return 2;
    }

    QApplication app(argc, argv);
    QStringList labels;
    for (const auto &choice : choices) labels << QString::fromUtf8(choice.label);
    bool accepted = false;
    const QString selected = QInputDialog::getItem(nullptr, QObject::tr("Nabu Color Profiles"),
        QObject::tr("Select the profile matching the panel revision:"), labels, 0, false, &accepted);
    if (!accepted) return 0;
    const int index = labels.indexOf(selected);
    if (index < 0 || index >= int(std::size(choices))) return 2;
    const Result result = apply(choices[index], false);
    QMessageBox message(result.status == 0 ? QMessageBox::Information : QMessageBox::Critical,
        QObject::tr("Nabu Color Profiles"),
        result.status == 0 ? QObject::tr("Profile applied. %1").arg(result.output) : result.output);
    message.setTextFormat(Qt::PlainText);
    message.exec();
    return result.status;
}
