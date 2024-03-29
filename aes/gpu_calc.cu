#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "calculation.h"

static int Sbox[256] = {
  0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
  0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
  0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
  0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
  0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
  0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
  0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
  0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
  0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
  0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
  0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
  0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
  0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
  0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
  0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
  0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
};

__device__ __host__ void datadump2(const char *c, const void *dt, int len)
{
  int i;
  unsigned char *cdt = (unsigned char *)dt;
  printf("%s", c);
  for (i = 0; i < len*4;i++) {
    printf("%02x", cdt[i]);
  }
  printf("\n");
}

__device__ void device_sub_bytes(int *state, const int *d_sbox) {
  int i, j;
  unsigned char *cb=(unsigned char*)state;
  for(i=0; i<NBb; i+=4){
    for(j=0; j<4; j++){
      cb[i+j] = d_sbox[cb[i+j]];
    }
  }
}

__device__ void device_shift_rows(int *state) {
  int i, j, i4;
  unsigned char *cb = (unsigned char*)state;
  unsigned char cw[NBb];
  for (i = 0; i < NBb; i++) {
    cw[i] = cb[i];
  }

  for (i = 0;i < NB; i+=4) {
    i4 = i*4;
    for(j = 1; j < 4; j++){
      cw[i4+j+0*4] = cb[i4+j+((j+0)&3)*4];
      cw[i4+j+1*4] = cb[i4+j+((j+1)&3)*4];
      cw[i4+j+2*4] = cb[i4+j+((j+2)&3)*4];
      cw[i4+j+3*4] = cb[i4+j+((j+3)&3)*4];
    }
  }
  for (i = 0; i < NBb; i++) {
    cb[i] = cw[i];
  }
}

__device__ unsigned char device_dataget(void* data, int n)
{
  return(((unsigned char*)data)[n]);
}

__device__ int device_mul(int dt,int n)
{
  int i, x = 0;
  for(i = 8; i > 0; i >>= 1)
    {
      x <<= 1;
      if(x & 0x100)
        x = (x ^ 0x1b) & 0xff;
      if((n & i))
        x ^= dt;
    }
  return(x);
}

__device__ void device_mix_columns(int *state) {
  int i, i4, x;
  for(i = 0; i< NB; i++){
    i4 = i*4;
    x  =  device_mul(device_dataget(state,i4+0),2) ^
          device_mul(device_dataget(state,i4+1),3) ^
          device_mul(device_dataget(state,i4+2),1) ^
          device_mul(device_dataget(state,i4+3),1);
    x |= (device_mul(device_dataget(state,i4+1),2) ^
          device_mul(device_dataget(state,i4+2),3) ^
          device_mul(device_dataget(state,i4+3),1) ^
          device_mul(device_dataget(state,i4+0),1)) << 8;
    x |= (device_mul(device_dataget(state,i4+2),2) ^
          device_mul(device_dataget(state,i4+3),3) ^
          device_mul(device_dataget(state,i4+0),1) ^
          device_mul(device_dataget(state,i4+1),1)) << 16;
    x |= (device_mul(device_dataget(state,i4+3),2) ^
          device_mul(device_dataget(state,i4+0),3) ^
          device_mul(device_dataget(state,i4+1),1) ^
          device_mul(device_dataget(state,i4+2),1)) << 24;
    state[i] = x;
  }
}

__device__ void device_add_round_key(int *state, int *w, int n)
{
  int i;
  for (i = 0; i < NB; i++) {
    state[i] ^= w[i + NB * n];
  }
}

__global__ void device_aes_encrypt(unsigned char *pt, int *rkey,
    unsigned char *ct, const int *d_sbox, long int size) {
  //printf("device_mul( 0x12, 3)  : %d\n", device_mul(0x12, 3));

  //This kernel executes AES encryption on a GPU.
  //Please modify this kernel!!
  int thread_id = blockDim.x * blockIdx.x + threadIdx.x;

  int rnd;
  int data[NB];
  memcpy(data , pt + 16 * thread_id, NBb);
  //datadump2("Plaintext        : ", data, 4);

  device_add_round_key(data, rkey, 0);

  for (rnd = 1; rnd < NR; rnd++) {
    device_sub_bytes(data, d_sbox);
    device_shift_rows(data);
    device_mix_columns(data);
    device_add_round_key(data, rkey, rnd);
  }

  device_sub_bytes(data, d_sbox);
  device_shift_rows(data);
  device_add_round_key(data, rkey, rnd);

  for (int i = 0; i < NB; i++) {
    (((int *)ct) + 4 * thread_id)[i] = data[i];
  }

  if (thread_id == 0) {
    datadump2("ID 0 : ", ct, 4);
  }
}

void launch_aes_kernel(unsigned char *pt, int *rk, unsigned char *ct, long int size){

  //This function launches the AES kernel.
  //Please modify this function for AES kernel.
  //In this function, you need to allocate the device memory and so on.

  unsigned char *d_pt, *d_ct;
  int *d_rkey;
  int *d_sbox;

  //dim3 dim_grid(425984,1,1), dim_block(512,1,1);
  //dim3 dim_grid(53248,1,1), dim_block(4096,1);
  dim3 dim_grid(53248,1,1), dim_block(256,1);

  cudaMalloc((void **)&d_pt, sizeof(unsigned char)*size);
  cudaMalloc((void **)&d_rkey, sizeof(int) * 44);
  cudaMalloc((void **)&d_sbox, sizeof(int) * 256);
  cudaMalloc((void **)&d_ct, sizeof(unsigned char)*size);

  cudaMemset(d_pt, 0, sizeof(unsigned char) * size);
  cudaMemcpy(d_pt, pt, sizeof(unsigned char) * size, cudaMemcpyHostToDevice);
  cudaMemcpy(d_rkey, rk, sizeof(int)*44, cudaMemcpyHostToDevice);
  cudaMemcpy(d_sbox, Sbox, sizeof(int) * 256, cudaMemcpyHostToDevice);

  device_aes_encrypt<<<dim_grid, dim_block>>>(d_pt, d_rkey, d_ct, d_sbox, size);
  cudaMemcpy(ct, d_ct, sizeof(unsigned char) * size, cudaMemcpyDeviceToHost);

  cudaFree(d_sbox);
  cudaFree(d_pt);
  cudaFree(d_rkey);
  cudaFree(d_ct);
  datadump2("Ciphertext on GPU: ", ct, 512);

/*  for(int i = 0; i < (size / 16); i++){
    datadump2("Ciphertext on GPU: ", ct+16*i, 4);
    printf("\n");
  } */
}


