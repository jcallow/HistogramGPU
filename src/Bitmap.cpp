/*
 * Bitmap.cpp
 *
 *  Created on: Nov 30, 2015
 *      Author: john
 */
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "Bitmap.h"

namespace std {

/*
 * Stores bmp pixel data
 */

Bitmap::Bitmap(char *fname) {
	x_dim=y_dim=0;
	pixels_red=NULL;
	pixels_blue=NULL;
	pixels_green=NULL;

	FILE *ifile;
	ifile = fopen(fname, "rb");
	unsigned char info[54];

	fread(info, sizeof(unsigned char), 54, ifile);

	x_dim = *(int*)&info[18];
	y_dim = *(int*)&info[22];

	int size = x_dim*y_dim;
	unsigned char* pixels = new unsigned char[3*size];
	fread(pixels, sizeof(unsigned char), 3*size, ifile);
	fclose(ifile);

	pixels_red = new unsigned char[size];
	pixels_blue = new unsigned char[size];
	pixels_green = new unsigned char[size];

	for (int i = 0; i < size; i++) {
		pixels_blue[i] = pixels[3*i];
		pixels_green[i] = pixels[3*i+1];
		pixels_red[i] = pixels[3*i+2];
	}

}

Bitmap::~Bitmap() {
	delete[] pixels_red;
	delete[] pixels_blue;
	delete[] pixels_green;
}

} /* namespace std */
