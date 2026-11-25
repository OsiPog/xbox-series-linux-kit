#include <windows.h>
#include <stdio.h>
#include <psapi.h>
/* map N 64KiB views of one section (like VIctory's per-page aliases), then
   query (GetMappedFileName -> server get_mapping_filename = find_mapped_addr),
   then unmap in FIFO order (find_mapped_view). Also checks overlap refusal. */
int main(int argc, char **argv)
{
    int n = argc > 1 ? atoi(argv[1]) : 20000, i, bad = 0;
    LARGE_INTEGER f, t0, t1, t2, t3;
    HANDLE sec = CreateFileMappingA(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE, 0, 0x10000, NULL);
    void **v = calloc(n, sizeof(void*));
    char name[512];
    QueryPerformanceFrequency(&f); QueryPerformanceCounter(&t0);
    for (i = 0; i < n; i++) { v[i] = MapViewOfFile(sec, FILE_MAP_WRITE, 0, 0, 0x10000); if (!v[i]) { printf("map fail %d %lu\n", i, GetLastError()); n = i; break; } }
    QueryPerformanceCounter(&t1);
    /* aliasing correctness: write via one view, read via another */
    *(volatile int*)v[0] = 1234; if (*(volatile int*)v[n-1] != 1234) bad++;
    /* overlap: mapping at an existing view address must fail */
    if (MapViewOfFileEx(sec, FILE_MAP_WRITE, 0, 0, 0x10000, (char*)v[n/2])) bad++;
    for (i = 0; i < n; i += 7) { if (!GetMappedFileNameA(GetCurrentProcess(), (char*)v[i] + 0x1234, name, sizeof name) && GetLastError() == ERROR_INVALID_PARAMETER) ; }
    QueryPerformanceCounter(&t2);
    for (i = 0; i < n; i++) if (!UnmapViewOfFile(v[i])) bad++;
    QueryPerformanceCounter(&t3);
    /* unmapping again must fail */
    if (UnmapViewOfFile(v[0])) bad++;
    printf("n=%d map=%.3fs query=%.3fs unmap=%.3fs bad=%d\n", n,
        (double)(t1.QuadPart-t0.QuadPart)/f.QuadPart, (double)(t2.QuadPart-t1.QuadPart)/f.QuadPart,
        (double)(t3.QuadPart-t2.QuadPart)/f.QuadPart, bad);
    return bad;
}
