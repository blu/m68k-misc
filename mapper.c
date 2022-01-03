#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>

int main(int argc, char **argv)
{
	if (argc != 2) {
		fprintf(stderr, "usage: %s filename\n", argv[0]);
		return -1;
	}

	const int fd = open(argv[1], O_RDONLY);

	if (fd < 0) {
		fprintf(stderr, "error: cannot open file %s\n", argv[1]);
		return -1;
	}

	struct stat sb;

	if (fstat(fd, &sb) < 0) {
		close(fd);
		fprintf(stderr, "error: cannot stat file %s\n", argv[1]);
		return -1;
	}

	if (sb.st_size != 594) {
		close(fd);
		fprintf(stderr, "error: unexpected size of file %s\n", argv[1]);
		return -1;
	}

	char *p = (char *)mmap(NULL, sb.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	close(fd);

	if (!p) {
		fprintf(stderr, "error: cannon mmap file %s\n", argv[1]);
		return -1;
	}

	uint8_t map[8][8];

	for (unsigned iy = 0; iy < 8; iy++) {
		const char *row = (iy + 1) * 66 + 1 + p;
		for (unsigned ix = 0; ix < 8; ix++) {
			uint8_t byte = 0;
			for (unsigned ib = 0; ib < 8; ib++) {
				byte = (byte << 1) | (row[ix * 8 + ib] != '.');
			}
			map[iy][ix] = byte;
		}
	}

	munmap(p, sb.st_size);

	const int fe = open("mapped.bin", O_CREAT | O_WRONLY, S_IRUSR | S_IRGRP | S_IROTH);

	if (fe < 0) {
		fprintf(stderr, "error: cannot open file 'mapped.bin' for writing\n");
		return -1;
	}

	const ssize_t written = write(fe, map, sizeof(map));
	close(fe);

	if (sizeof(map) != written) {
		fprintf(stderr, "error: cannot write file 'mapped.bin'\n");
		return -1;
	}

	return 0;
}
