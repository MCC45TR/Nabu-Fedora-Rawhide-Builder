/* SPDX-License-Identifier: MIT
 * Minimal read-only AArch64 UEFI CurrentEL probe for Xiaomi Pad 5 (nabu).
 * It does not modify firmware variables, storage, or platform state.
 */

typedef unsigned long long UINT64;
typedef unsigned long long UINTN;
typedef unsigned short CHAR16;
typedef void *EFI_HANDLE;
typedef UINT64 EFI_STATUS;

#define EFI_SUCCESS 0

typedef struct {
    UINT64 Signature;
    unsigned int Revision;
    unsigned int HeaderSize;
    unsigned int CRC32;
    unsigned int Reserved;
} EFI_TABLE_HEADER;

typedef struct _EFI_SIMPLE_TEXT_INPUT_PROTOCOL EFI_SIMPLE_TEXT_INPUT_PROTOCOL;
typedef struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;
typedef struct _EFI_BOOT_SERVICES EFI_BOOT_SERVICES;

typedef struct {
    unsigned short ScanCode;
    CHAR16 UnicodeChar;
} EFI_INPUT_KEY;

struct _EFI_SIMPLE_TEXT_INPUT_PROTOCOL {
    EFI_STATUS (*Reset)(EFI_SIMPLE_TEXT_INPUT_PROTOCOL *, unsigned char);
    EFI_STATUS (*ReadKeyStroke)(EFI_SIMPLE_TEXT_INPUT_PROTOCOL *, EFI_INPUT_KEY *);
    void *WaitForKey;
};

struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
    EFI_STATUS (*Reset)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *, unsigned char);
    EFI_STATUS (*OutputString)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *, const CHAR16 *);
    void *TestString;
    void *QueryMode;
    void *SetMode;
    void *SetAttribute;
    EFI_STATUS (*ClearScreen)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *);
    void *SetCursorPosition;
    void *EnableCursor;
    void *Mode;
};

struct _EFI_BOOT_SERVICES {
    EFI_TABLE_HEADER Hdr;
    void *RaiseTPL;
    void *RestoreTPL;
    void *AllocatePages;
    void *FreePages;
    void *GetMemoryMap;
    void *AllocatePool;
    void *FreePool;
    void *CreateEvent;
    void *SetTimer;
    EFI_STATUS (*WaitForEvent)(UINTN, void **, UINTN *);
};

typedef struct {
    EFI_TABLE_HEADER Hdr;
    CHAR16 *FirmwareVendor;
    unsigned int FirmwareRevision;
    unsigned int Pad;
    EFI_HANDLE ConsoleInHandle;
    EFI_SIMPLE_TEXT_INPUT_PROTOCOL *ConIn;
    EFI_HANDLE ConsoleOutHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *ConOut;
    EFI_HANDLE StandardErrorHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *StdErr;
    void *RuntimeServices;
    EFI_BOOT_SERVICES *BootServices;
    UINTN NumberOfTableEntries;
    void *ConfigurationTable;
} EFI_SYSTEM_TABLE;

static void print(EFI_SYSTEM_TABLE *st, const CHAR16 *text)
{
    st->ConOut->OutputString(st->ConOut, text);
}

EFI_STATUS efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *st)
{
    UINT64 current_el;
    EFI_INPUT_KEY key;
    UINTN index;

    (void)image;
    __asm__ volatile("mrs %0, CurrentEL" : "=r"(current_el));
    current_el = (current_el >> 2) & 3ULL;

    st->ConOut->ClearScreen(st->ConOut);
    print(st, L"SENEMOS Nabu CurrentEL probe\r\n\r\n");

    if (current_el == 2) {
        print(st, L"Result: EL2\r\n");
        print(st, L"Firmware exposes EL2; test the separate KVM kernel next.\r\n");
    } else if (current_el == 1) {
        print(st, L"Result: EL1\r\n");
        print(st, L"Firmware owns EL2; an ESP application cannot enable KVM.\r\n");
    } else if (current_el == 3) {
        print(st, L"Result: EL3 (unexpected for non-secure UEFI)\r\n");
    } else {
        print(st, L"Result: EL0 (unexpected for UEFI)\r\n");
    }

    print(st, L"\r\nRead-only probe: no storage, EFI variable, or firmware write.\r\n");
    print(st, L"Press any key to return to the boot manager.\r\n");

    st->ConIn->Reset(st->ConIn, 0);
    st->BootServices->WaitForEvent(1, &st->ConIn->WaitForKey, &index);
    st->ConIn->ReadKeyStroke(st->ConIn, &key);

    return EFI_SUCCESS;
}
