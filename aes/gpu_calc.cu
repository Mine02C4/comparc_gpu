#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "calculation.h"


void device_sub_bytes(int *state, int *d_sbox) {
  int i, j;
  unsigned char *cb=(unsigned char*)state;
  for(i=0; i<NBb; i+=4){
    for(j=0; j<4; j++){
      cb[i+j] = d_sbox[cb[i+j]];
    }
  }
}

void device_shift_rows(int *state) {
  int i, j, i4;
  unsigned char *cb = (unsigned char*)state;
  unsigned char cw[NBb];
  memcpy(cw, cb, sizeof(cw));

  for (i = 0;i < NB; i+=4) {
    i4 = i*4;
    for(j = 1; j < 4; j++){
      cw[i4+j+0*4] = cb[i4+j+((j+0)&3)*4];
      cw[i4+j+1*4] = cb[i4+j+((j+1)&3)*4];
      cw[i4+j+2*4] = cb[i4+j+((j+2)&3)*4];
      cw[i4+j+3*4] = cb[i4+j+((j+3)&3)*4];
    }
  }
  memcpy(cb,cw,sizeof(cw));
}

void device_mix_columns(int *state) {
  int i, i4, x;
  for(i = 0; i< NB; i++){
    i4 = i*4;
    x  =  mul(dataget(state,i4+0),2) ^
          mul(dataget(state,i4+1),3) ^
          mul(dataget(state,i4+2),1) ^
          mul(dataget(state,i4+3),1);
    x |= (mul(dataget(state,i4+1),2) ^
          mul(dataget(state,i4+2),3) ^
          mul(dataget(state,i4+3),1) ^
          mul(dataget(state,i4+0),1)) << 8;
    x |= (mul(dataget(state,i4+2),2) ^
          mul(dataget(state,i4+3),3) ^
          mul(dataget(state,i4+0),1) ^
          mul(dataget(state,i4+1),1)) << 16;
    x |= (mul(dataget(state,i4+3),2) ^
          mul(dataget(state,i4+0),3) ^
          mul(dataget(state,i4+1),1) ^
          mul(dataget(state,i4+2),1)) << 24;
    state[i] = x;
  }
}

void device_add_round_key(int *state, int *w, int n)
{
  int i;
  for (i = 0; i <NB; i++) {
    state[i] ^= w[i + NB * n];
  }
}

__global__ void device_aes_encrypt(unsigned char *pt, int *rkey,
    unsigned char *ct, const int *d_sbox, long int size) {

  //This kernel executes AES encryption on a GPU.
  //Please modify this kernel!!
  int thread_id = blockDim.x * blockIdx.x + threadIdx.x;

  if(thread_id == 0)
    printf("size = %ld\n", size);

  printf("You can use printf function to eliminate bugs in your kernel.\n");
  printf("This thread ID is %d.\n", thread_id);

  int rnd;
  int data[NB];
  memcpy(data , pt + 16 * thread_id, NBb);

  device_add_round_key(data, rkey, 0);

  for (rnd = 1; rnd < NR; rnd++) {
    device_sub_bytes(data, d_sbox);
    device_shift_rows(data);
    device_mix_columns(data, rkey);
    device_add_round_key(data, rkey, rnd);
  }

  device_sub_bytes(data, d_sbox);
  device_shift_rows(data);
  device_add_round_key(data, rkey, rnd);

  memcpy(ct + 16 * thread_id , data, NBb);
}

void launch_aes_kernel(unsigned char *pt, int *rk, unsigned char *ct, long int size){

  //This function launches the AES kernel.
  //Please modify this function for AES kernel.
  //In this function, you need to allocate the device memory and so on.

  unsigned char *d_pt, *d_ct;
  int *d_rkey;
  int *d_sbox;

  dim3 dim_grid(1,1,1), dim_block(1,1,1);

  cudaMalloc((void **)&d_pt, sizeof(unsigned char)*size);
  cudaMalloc((void **)&d_rkey, sizeof(int)*44);
  cudaMalloc((void **)&d_ct, sizeof(unsigned char)*size);
  cudaMalloc((void **)&d_sbox, sizeof(int) * 256);

  cudaMemset(d_pt, 0, sizeof(unsigned char)*size);
  cudaMemcpy(d_pt, pt, sizeof(unsigned char)*size, cudaMemcpyHostToDevice);
  cudaMemcpy(d_rkey, rk, sizeof(int)*44, cudaMemcpyHostToDevice);
  cudaMemcpy(d_sbox, Sbox, sizeof(int) * 256, cudaMemcpyHostToDevice);

  device_aes_encrypt<<<dim_grid, dim_block>>>(d_pt, d_rkey, d_ct, d_sbox, size);
  cudaMemcpy(ct, d_ct, sizeof(unsigned char)*size, cudaMemcpyDeviceToHost);

  cudaFree(d_sbox);
  cudaFree(d_pt);
  cudaFree(d_rkey);
  cudaFree(d_ct);
}












