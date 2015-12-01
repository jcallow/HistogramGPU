/*
 * Bitmap.h
 *
 *  Created on: Nov 30, 2015
 *      Author: john
 */

#ifndef BITMAP_H_
#define BITMAP_H_

namespace std {

class Bitmap {
public:
	Bitmap(char *fname);
	~Bitmap();

	int x_dim;
	int y_dim;
	int num_colors = 255;
	unsigned char *pixels_red;
	unsigned char *pixels_blue;
	unsigned char *pixels_green;


};

} /* namespace std */

#endif /* BITMAP_H_ */
