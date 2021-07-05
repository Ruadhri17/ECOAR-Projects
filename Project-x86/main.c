//Program Draw a Line in 8bpp bitmap using Bresenham's Line Algorithm
#include <stdio.h>
#include <stdlib.h>

extern void line(void *img, int xs, int ys, int xe, int ye, unsigned int color);

int main(int argc, char *argv[])
{
    int xs, ys, xe, ye;
    unsigned int color;
    long size;
    char *buffer;
    FILE *input, *output;

    if(argc != 7)
        {
            printf("Not enough input arguments!");
            return -1;
        }
    else
        {
            xs = atoi(argv[2]);
            ys = atoi(argv[3]);
            xe = atoi(argv[4]);
            ye = atoi(argv[5]);
            if(xs < 0 || ys < 0 || xe < 0 || ye < 0 )
                {
                    printf("Cordinates cannot be negative!");
                    return -1;
                }
            if(xs >= 0x10000 || ys >= 0x10000 || xe >= 0x10000 || ye >= 0x10000 )
                {
                   printf("This program cannot procede such big values!");
                   return -1;
                }
            if(xs > xe)
                {
                    int temp = xe;
                    xe = xs;
                    xs = temp;
                    temp = ye;
                    ye = ys;
                    ys = temp;
                }
            if((color = atoi(argv[6])) > 255)
                {
                    printf("Given color is not in 8bpp range!");
                    return -1;
                }
        }
    input = fopen(argv[1], "rb");  
    if(input == NULL)
        {
            printf("Unexpected error while opening the file!");
            return -1;
        }
    else
        {
            output = fopen("out.bmp", "wb");
            fseek(input, 0, SEEK_END);
            size = ftell(input);
            fseek(input, 0, SEEK_SET);
            buffer = malloc(size);
            fread(buffer, 1, size, input);
            if((int)buffer[28] != 8)
                {
                    printf("Given file is not 8bpp bitmap!");
                    free(buffer);
                    fclose(input);
                    fclose(output);
                    return -1;
                }
            if((int)buffer[18]-1 < xs || (int)buffer[18]-1 < xe || (int)buffer[22]-1 < ys || (int)buffer[22]-1 < ye)
                {
                    printf("Given coordinates are out of bitmap range!");
                    free(buffer);
                    fclose(input);
                    fclose(output);
                    return -1;    
                } 
            line(buffer, xs, ys, xe, ye, color);
            fwrite(buffer, 1, size, output);
            free(buffer);
            fclose(input);
            fclose(output);
        }
    return 0;
}