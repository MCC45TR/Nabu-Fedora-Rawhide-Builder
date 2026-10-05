/* SPDX-License-Identifier: MIT */
/* Build-time tests: static upstream helpers, no real process/device access. */
#include "evdi_procfs.c"

static void check_record(const char *record, bool expected)
{
    FILE *stream = tmpfile();
    assert(stream != NULL);
    assert(fputs(record, stream) >= 0);
    rewind(stream);
    char *name = process_name(stream);
    assert(is_name_Xorg(name) == expected);
    free(name);
    fclose(stream);
}

int main(void)
{
    check_record("123 (Xorg) S 1 2 3", true);
    check_record("123 (kwin_wayland) S 1", false);
    check_record("", false);
    check_record("123", false);
    check_record("broken (Xorg)", false);
    assert(!is_name_Xorg(NULL));
    assert(open_process_folder("../self") == NULL);
    assert(open_process_folder("123456789012345678901") == NULL);
    puts("PASS: bounded procfs paths and failed/normal process record parsing");
    return 0;
}
