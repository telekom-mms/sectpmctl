#include <argon2.h>

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

void showHelp() {
    fprintf(stderr, "sectpmctl-hash tool to generate argon2id hashes\n");
    fprintf(stderr, "options:\n");
    fprintf(stderr, "sectpmctl hash --salt <32 byte file> --time <number> --memory <kilobytes> --cpus <number> <password>\n");
}

int main(int argc, char **argv)
{
    char* saltFile = "";
    char* password = "";
    size_t time = 0;
    size_t memory = 0;
    size_t cpus = 0;

    size_t i = 0;    
    if (argc==10) {
        for (i=0; i<4; i++) {
            if (strcmp(argv[1+(i*2)], "--salt")==0) {
                saltFile = argv[1+(i*2)+1];
            } else if (strcmp(argv[1+(i*2)], "--time")==0) {
                time = atoi(argv[1+(i*2)+1]);
            } else if (strcmp(argv[1+(i*2)], "--memory")==0) {
                memory = atoi(argv[1+(i*2)+1]);
            } else if (strcmp(argv[1+(i*2)], "--cpus")==0) {
                cpus = atoi(argv[1+(i*2)+1]);
            }
        }
        password = argv[9];
    } else {
        showHelp();
        exit(1);
    }
    
    if ((strlen(saltFile)==0) || (strlen(password)==0) || (time==0) || (memory==0) || (cpus==0)) {
        showHelp();
        exit(1);
    }
    
    uint32_t hashlen = 32;
    uint8_t hash[hashlen];

    uint32_t saltlen = 32;  
    uint8_t salt[saltlen];
    
    FILE *ptr;
    ptr = fopen(saltFile,"rb");
    if (ptr == NULL) {
        fprintf(stderr, "error: could not read salt file %s\n", saltFile);
        exit(1);
    }
    if (fread(salt, 1, saltlen, ptr) != saltlen) {
        fprintf(stderr, "error: expected length of salt is %u\n", saltlen);
        fclose(ptr);
        exit(1);
    }
    fclose(ptr);

    argon2_context context = {
        hash,
        hashlen,
        password,
        strlen(password),
        salt,
        saltlen,
        NULL, 0,
        NULL, 0,
        time, memory, cpus, cpus,
        ARGON2_VERSION_13,
        NULL, NULL,
        ARGON2_DEFAULT_FLAGS
    };

    int rc = argon2id_ctx(&context);
    if (rc != ARGON2_OK) {
        fprintf(stderr, "error: %s\n", argon2_error_message(rc));
        exit(1);
    }

    for (unsigned int i=0; i < hashlen; i++) {
        fprintf(stdout, "%02x", hash[i]);
    }
    fprintf(stdout, "\n");
    
    return 0;
}

