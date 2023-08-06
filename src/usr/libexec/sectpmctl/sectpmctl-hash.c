#include <argon2.h>

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <unistd.h>

int main(int argc, char **argv)
{
    // WORK IN PROGRESS

    uint32_t hashlen = 32;
    uint8_t hash[hashlen];

    uint32_t saltlen = 32;
    uint8_t salt[saltlen];
    FILE *ptr;
    ptr = fopen(argv[2],"rb");
    fread(salt,saltlen,1,ptr); 
    fclose(ptr);

    uint32_t iterations = 4;
    uint32_t memory = 1048576;
    uint32_t threads = 4;

    argon2_context context = {
        hash,
        hashlen,
        argv[3],
        strlen(argv[3]),
        salt,
        saltlen,
        NULL, 0,
        NULL, 0,
        iterations, memory, threads, threads,
        ARGON2_VERSION_13,
        NULL, NULL,
        ARGON2_DEFAULT_FLAGS
    };

    int rc = argon2id_ctx(&context);
    if (rc != ARGON2_OK) {
        fprintf(stderr, "error: %s\n", argon2_error_message(rc));
        return 0
    }

    for (unsigned int i=0; i < hashlen; i++) {
        printf("%02x", hash[i]);
    }
    printf( "\n" );
    
    return 0;
}

