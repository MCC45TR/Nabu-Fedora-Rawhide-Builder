// SPDX-License-Identifier: MIT
// Parse with ALSA itself; this never opens a sound card or writes controls.
#include <alsa/asoundlib.h>
#include <cassert>
#include <cstring>
#include <string>
int main(int argc, char **argv) {
    assert(argc == 2);
    snd_input_t *input = nullptr;
    snd_config_t *root = nullptr, *node = nullptr;
    assert(snd_input_stdio_open(&input, argv[1], "r") >= 0);
    assert(snd_config_top(&root) >= 0);
    assert(snd_config_load(root, input) >= 0);
    snd_input_close(input);
    assert(snd_config_search(root, "SectionDevice.Speaker.Value.PlaybackChannels", &node) >= 0);
    long channels = 0;
    assert(snd_config_get_integer(node, &channels) >= 0 && channels == 4);
    for (const auto &sequence : {std::string("EnableSequence"), std::string("DisableSequence")}) {
        const auto path = "SectionModifier.ArchReferenceGain." + sequence;
        assert(snd_config_search(root, path.c_str(), &node) >= 0);
        snd_config_iterator_t it, next;
        int commands = 0, gains = 0;
        snd_config_for_each(it, next, node) {
            const char *text = nullptr;
            assert(snd_config_get_string(snd_config_iterator_entry(it), &text) >= 0);
            const std::string value(text);
            if (value == "cset") commands++;
            else {
                const auto expected = sequence == "EnableSequence" ? "Analog PCM Volume' 8" : "Analog PCM Volume' 0";
                assert(value.ends_with(expected));
                gains++;
            }
        }
        assert(commands == 4 && gains == 4);
    }
    assert(snd_config_search(root, "SectionVerb.EnableSequence", &node) >= 0);
    snd_config_iterator_t it, next;
    int defaults = 0;
    snd_config_for_each(it, next, node) {
        const char *text = nullptr;
        assert(snd_config_get_string(snd_config_iterator_entry(it), &text) >= 0);
        const std::string value(text);
        if (value.find("Analog PCM Volume") != std::string::npos) {
            assert(value.ends_with("' 0")); defaults++;
        }
    }
    assert(defaults == 4);
    snd_config_delete(root);
    return 0;
}
