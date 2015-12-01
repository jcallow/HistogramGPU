/*
 * main.cu
 *
 *  Created on: Nov 30, 2015
 *      Author: john
 */


#include "Bitmap.h"
#include <iostream>
#include <cuda.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

using namespace std;

const int BINS = 256;
const int BINS4ALL = BINS*16; // Using half warp size since I need 3 sets, and these bins need to fit in 48kb shared memory.

void CPU_histogram (unsigned char *in_red, unsigned char *in_blue, unsigned char *in_green, int N, int *h_red, int *h_blue, int *h_green, int bins)
{
  int i;
  // initialize histogram counts
  for (i = 0; i < bins; i++) {
	  h_red[i] = 0;
  	  h_blue[i] = 0;
  	  h_green[i] = 0;
  }

  // accummulate counts
  for (i = 0; i < N; i++) {
	  h_red[in_red[i]]++;
	  h_blue[in_blue[i]]++;
	  h_green[in_green[i]]++;
  }

}

__device__
void write_shared(int *in, int* bank, int i) {
	int temp = in[i];
	int v = temp & 0xFF;
	int v2 = (temp >> 8) & 0xFF;
	int v3 = (temp >> 16) & 0xFF;
	int v4 = (temp >> 24) & 0xFF;
	atomicAdd (bank + (v << 4), 1);
	atomicAdd (bank + (v2 << 4), 1);
	atomicAdd (bank + (v3 << 4), 1);
	atomicAdd (bank + (v4 << 4), 1);
}

__global__
void GPU_histogramRGB_atomic (int *in_red, int *in_blue, int *in_green, int N, int *h_red, int *h_blue, int *h_green) {
	int gloID = blockIdx.x*blockDim.x + threadIdx.x;
	int locID = threadIdx.x;
	int GRIDSIZE = gridDim.x*blockDim.x;

	__shared__ int localH_red[BINS4ALL];
	__shared__ int localH_blue[BINS4ALL];
	__shared__ int localH_green[BINS4ALL];

	int bankID = locID & 0x0F;
	int i;

	// initialize the local shared-memory bins
	for (i = locID; i < BINS4ALL; i += blockDim.x) {
		localH_red[i] = 0;
		localH_blue[i] = 0;
		localH_green[i] = 0;
	}

	__syncthreads();

	int *mySharedBank_red = localH_red + bankID;
	int *mySharedBank_blue = localH_blue + bankID;
	int *mySharedBank_green = localH_green + bankID;

	for (i = gloID; i < N; i += GRIDSIZE) {
		write_shared(in_red, mySharedBank_red, i);
		write_shared(in_blue, mySharedBank_blue, i);
		write_shared(in_green, mySharedBank_green, i);
	}

	__syncthreads ();


	for (i = locID; i < BINS4ALL; i += blockDim.x) {
		atomicAdd (h_red + (i >> 4), localH_red[i]);
		atomicAdd (h_blue + (i >> 4), localH_blue[i]);
		atomicAdd (h_green + (i >> 4), localH_green[i]);
	}

}


int main (int argc, char **argv) {
	Bitmap* bmp = new Bitmap("CAT2.bmp");

	int *d_in_red, *d_in_blue, *d_in_green;
	int *h_in_red, *h_in_blue, *h_in_green;
	int *cpu_hist_red, *cpu_hist_blue, *cpu_hist_green;
	int *d_hist_red, *d_hist_blue, *d_hist_green;
	int *hist_red, *hist_blue, *hist_green;

	int bins, N;

	h_in_red = (int *) bmp->pixels_red;
	h_in_blue = (int *) bmp->pixels_blue;
	h_in_green = (int *) bmp->pixels_green;
	N = ceil((bmp->x_dim * bmp->y_dim) / 4.0);

	bins = 256;

	hist_red = (int *) malloc (bins * sizeof (int));
	hist_blue = (int *) malloc (bins * sizeof (int));
	hist_green = (int *) malloc (bins * sizeof (int));

	cpu_hist_red = (int *) malloc (bins * sizeof (int));
	cpu_hist_blue = (int *) malloc (bins * sizeof (int));
	cpu_hist_green = (int *) malloc (bins * sizeof (int));

	CPU_histogram(bmp->pixels_red, bmp->pixels_blue, bmp->pixels_green, bmp->x_dim*bmp->y_dim, cpu_hist_red, cpu_hist_blue, cpu_hist_green, bins);



    // allocate and copy
    cudaMalloc ((void **) &d_in_red, sizeof (int) * N);
    cudaMalloc ((void **) &d_hist_red, sizeof (int) * bins);
    cudaMemcpy (d_in_red, h_in_red, sizeof (int) * N, cudaMemcpyHostToDevice);
    cudaMemset (d_hist_red, 0, bins * sizeof (int));

    cudaMalloc ((void **) &d_in_blue, sizeof (int) * N);
    cudaMalloc ((void **) &d_hist_blue, sizeof (int) * bins);
    cudaMemcpy (d_in_blue, h_in_blue, sizeof (int) * N, cudaMemcpyHostToDevice);
    cudaMemset (d_hist_blue, 0, bins * sizeof (int));

    cudaMalloc ((void **) &d_in_green, sizeof (int) * N);
    cudaMalloc ((void **) &d_hist_green, sizeof (int) * bins);
    cudaMemcpy (d_in_green, h_in_green, sizeof (int) * N, cudaMemcpyHostToDevice);
    cudaMemset (d_hist_green, 0, bins * sizeof (int));

    // initialize two events
    cudaStream_t str;
    cudaEvent_t startT, endT;
    float duration;
    cudaStreamCreate (&str);
    cudaEventCreate (&startT);
    cudaEventCreate (&endT);

    cudaEventRecord (startT, str);
	GPU_histogramRGB_atomic <<<32, 1024, 0, str >>> (d_in_red, d_in_blue, d_in_green, N, d_hist_red, d_hist_blue, d_hist_green);

	cudaEventRecord (endT, str);
	cudaEventSynchronize (endT);

	cudaMemcpy (hist_red, d_hist_red, sizeof (int) * bins, cudaMemcpyDeviceToHost);
	cudaMemcpy (hist_blue, d_hist_blue, sizeof (int) * bins, cudaMemcpyDeviceToHost);
	cudaMemcpy (hist_green, d_hist_green, sizeof (int) * bins, cudaMemcpyDeviceToHost);
	cudaEventElapsedTime (&duration, startT, endT);

	for (int i = 0; i < BINS; i++)
	    printf ("%i %i %i %i\n", i, hist_red[i], hist_blue[i], hist_green[i]);


	for (int i = 0; i < BINS; i++)
		if (cpu_hist_red[i] != hist_red[i] || cpu_hist_blue[i] != hist_blue[i] || cpu_hist_green[i] != hist_green[i])
			printf ("Calculation mismatch (static) at : %i\n", i);



	printf ("Kernel executed for %f ms\n", duration);

	cudaStreamDestroy (str);
	cudaEventDestroy (startT);
	cudaEventDestroy (endT);

	cudaFree ((void *) d_in_red);
	cudaFree ((void *) d_hist_red);
	free (hist_red);
	cudaFree ((void *) d_in_blue);
	cudaFree ((void *) d_hist_blue);
	free (hist_blue);
	cudaFree ((void *) d_in_green);
	cudaFree ((void *) d_hist_green);
	free (hist_green);

	cudaDeviceReset ();
	return 0;
}

