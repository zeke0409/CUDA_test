#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include <getopt.h>
#define HEADERSIZE 54   /* ヘッダのサイズ 54 = 14 + 40         */
#define PALLETSIZE 1024 /* パレットのサイズ                    */
#define MAXWIDTH 10000  /* 幅(pixel)の上限                     */
#define MAXHEIGHT 10000 /* 高さ(pixel) の上限                  */

/* x と y の交換のための マクロ関数 */
#define SWAP(x, y)      \
    {                   \
        typeof(x) temp; \
        temp = x;       \
        x = y;          \
        y = temp;       \
    }

#define BLOCK 5

unsigned char Bmp_headbuf[HEADERSIZE]; /* ヘッダを格納するための変数          */
unsigned char Bmp_Pallet[PALLETSIZE]; /* カラーパレットを格納                */

char Bmp_type[2];       /* ファイルタイプ "BM"                 */
unsigned long Bmp_size; /* bmpファイルのサイズ (バイト)        */
unsigned int Bmp_info_header_size; /* 情報ヘッダのサイズ = 40             */
unsigned int Bmp_header_size;      /* ヘッダサイズ = 54*/
long Bmp_height;           /* 高さ (ピクセル)                     */
long Bmp_width;            /* 幅   (ピクセル)                     */
unsigned short Bmp_planes; /* プレーン数 常に 1                   */
unsigned short Bmp_color;  /* 色 (ビット)     24                  */
long Bmp_comp;             /* 圧縮方法         0                  */
long Bmp_image_size; /* 画像部分のファイルサイズ (バイト)   */
long Bmp_xppm;       /* 水平解像度 (ppm)                    */
long Bmp_yppm;       /* 垂直解像度 (ppm)                    */

typedef struct { /* 1ピクセルあたりの赤緑青の各輝度     */
    unsigned char r;
    unsigned char g;
    unsigned char b;
} color;

typedef struct {
    long height;
    long width;
    color data[MAXHEIGHT][MAXWIDTH];
} img;
/*
   関数名: ReadBmp
   引数  : char *filename, img *imgp
   返り値: void
   動作  : bmp形式のファイル filename を開いて, その画像データを
           2次元配列 imgp->data に格納する. 同時に, ヘッダから読み込まれた
           画像の幅と高さをグローバル変数 Bmp_width とBmp_height にセットする.
*/
void ReadBmp(const char *filename, img *imgp) {
    int i, j;
    int Real_width;
    FILE *Bmp_Fp =
        fopen(filename, "rb"); /* バイナリモード読み込み用にオープン  */
    unsigned char *Bmp_Data; /* 画像データを1行分格納               */

    if (Bmp_Fp == NULL) {
        fprintf(stderr, "Error: file %s couldn\'t open for read!.\n", filename);
        exit(1);
    }

    /* ヘッダ読み込み */
    fread(Bmp_headbuf, sizeof(unsigned char), HEADERSIZE, Bmp_Fp);

    memcpy(&Bmp_type, Bmp_headbuf, sizeof(Bmp_type));
    if (strncmp(Bmp_type, "BM", 2) != 0) {
        fprintf(stderr, "Error: %s is not a bmp file.\n", filename);
        exit(1);
    }

    memcpy(&imgp->width, Bmp_headbuf + 18, sizeof(Bmp_width));
    memcpy(&imgp->height, Bmp_headbuf + 22, sizeof(Bmp_height));
    memcpy(&Bmp_color, Bmp_headbuf + 28, sizeof(Bmp_color));
    if (Bmp_color != 24) {
        fprintf(stderr,
                "Error: Bmp_color = %d is not implemented in this program.\n",
                Bmp_color);
        exit(1);
    }

    if (imgp->width > MAXWIDTH) {
        fprintf(stderr, "Error: Bmp_width = %ld > %d = MAXWIDTH!\n", Bmp_width,
                MAXWIDTH);
        exit(1);
    }

    if (imgp->height > MAXHEIGHT) {
        fprintf(stderr, "Error: Bmp_height = %ld > %d = MAXHEIGHT!\n",
                Bmp_height, MAXHEIGHT);
        exit(1);
    }

    Real_width = imgp->width * 3 +
                 imgp->width % 4; /* 4byte 境界にあわせるために実際の幅の計算 */

    /* 配列領域の動的確保. 失敗した場合はエラーメッセージを出力して終了 */
    if ((Bmp_Data = (unsigned char *)calloc(Real_width,
                                            sizeof(unsigned char))) == NULL) {
        fprintf(stderr, "Error: Memory allocation failed for Bmp_Data!\n");
        exit(1);
    }

    /* 画像データ読み込み */
    for (i = 0; i < imgp->height; i++) {
        fread(Bmp_Data, 1, Real_width, Bmp_Fp);
        for (j = 0; j < imgp->width; j++) {
            imgp->data[imgp->height - i - 1][j].b = Bmp_Data[j * 3];
            imgp->data[imgp->height - i - 1][j].g = Bmp_Data[j * 3 + 1];
            imgp->data[imgp->height - i - 1][j].r = Bmp_Data[j * 3 + 2];
        }
    }

    /* 動的に確保した配列領域の解放 */
    free(Bmp_Data);

    /* ファイルクローズ */
    fclose(Bmp_Fp);
}

/*
   関数名: WriteBmp
   引数  : char *filename, img *tp
   返り値: void
   動作  : 2次元配列 tp->data の内容を画像データとして, 24ビット
           bmp形式のファイル filename に書き出す.
*/
void WriteBmp(const char *filename, img *tp) {
    int i, j;
    int Real_width;
    FILE *Out_Fp = fopen(filename, "wb"); /* ファイルオープン */
    unsigned char *Bmp_Data; /* 画像データを1行分格納               */

    if (Out_Fp == NULL) {
        fprintf(stderr, "Error: file %s couldn\'t open for write!\n", filename);
        exit(1);
    }

    Bmp_color = 24;
    Bmp_header_size = HEADERSIZE;
    Bmp_info_header_size = 40;
    Bmp_planes = 1;

    Real_width = tp->width * 3 +
                 tp->width % 4; /* 4byte 境界にあわせるために実際の幅の計算 */

    /* 配列領域の動的確保. 失敗した場合はエラーメッセージを出力して終了 */
    if ((Bmp_Data = (unsigned char *)calloc(Real_width,
                                            sizeof(unsigned char))) == NULL) {
        fprintf(stderr, "Error: Memory allocation failed for Bmp_Data!\n");
        exit(1);
    }

    /* ヘッダ情報の準備 */
    Bmp_xppm = Bmp_yppm = 0;
    Bmp_image_size = tp->height * Real_width;
    Bmp_size = Bmp_image_size + HEADERSIZE;
    Bmp_headbuf[0] = 'B';
    Bmp_headbuf[1] = 'M';
    memcpy(Bmp_headbuf + 2, &Bmp_size, sizeof(Bmp_size));
    Bmp_headbuf[6] = Bmp_headbuf[7] = Bmp_headbuf[8] = Bmp_headbuf[9] = 0;
    memcpy(Bmp_headbuf + 10, &Bmp_header_size, sizeof(Bmp_header_size));
    Bmp_headbuf[11] = Bmp_headbuf[12] = Bmp_headbuf[13] = 0;
    memcpy(Bmp_headbuf + 14, &Bmp_info_header_size,
           sizeof(Bmp_info_header_size));
    Bmp_headbuf[15] = Bmp_headbuf[16] = Bmp_headbuf[17] = 0;
    memcpy(Bmp_headbuf + 18, &tp->width, sizeof(Bmp_width));
    memcpy(Bmp_headbuf + 22, &tp->height, sizeof(Bmp_height));
    memcpy(Bmp_headbuf + 26, &Bmp_planes, sizeof(Bmp_planes));
    memcpy(Bmp_headbuf + 28, &Bmp_color, sizeof(Bmp_color));
    memcpy(Bmp_headbuf + 34, &Bmp_image_size, sizeof(Bmp_image_size));
    memcpy(Bmp_headbuf + 38, &Bmp_xppm, sizeof(Bmp_xppm));
    memcpy(Bmp_headbuf + 42, &Bmp_yppm, sizeof(Bmp_yppm));
    Bmp_headbuf[46] = Bmp_headbuf[47] = Bmp_headbuf[48] = Bmp_headbuf[49] = 0;
    Bmp_headbuf[50] = Bmp_headbuf[51] = Bmp_headbuf[52] = Bmp_headbuf[53] = 0;

    /* ヘッダ情報書き出し */
    fwrite(Bmp_headbuf, sizeof(unsigned char), HEADERSIZE, Out_Fp);

    /* 画像データ書き出し */
    for (i = 0; i < tp->height; i++) {
        for (j = 0; j < tp->width; j++) {
            Bmp_Data[j * 3] = tp->data[tp->height - i - 1][j].b;
            Bmp_Data[j * 3 + 1] = tp->data[tp->height - i - 1][j].g;
            Bmp_Data[j * 3 + 2] = tp->data[tp->height - i - 1][j].r;
        }
        for (j = tp->width * 3; j < Real_width; j++) {
            Bmp_Data[j] = 0;
        }
        fwrite(Bmp_Data, sizeof(unsigned char), Real_width, Out_Fp);
    }

    /* 動的に確保した配列領域の解放 */
    free(Bmp_Data);

    /* ファイルクローズ */
    fclose(Out_Fp);
}

#define PI 3.1415

__global__ void GPU_process(img *picture_p, img *output_p, double rad,
                            int add_width, int add_height, int height,
                            int width) {
    int raw_y = blockIdx.x * blockDim.x + threadIdx.x;
    int raw_x = blockIdx.y * blockDim.y + threadIdx.y;
    if (raw_x < 0 || raw_y < 0 || raw_x >= width || raw_y >= height) {
        return;
    }
    for (double deg = 0; deg < 360; deg++) {
        double Rad = deg * PI / 180.0;
        int x = raw_x - picture_p->width / 2;
        int y = raw_y - picture_p->height / 2;
        int new_x = -x * cos(Rad) + y * sin(Rad);
        int new_y = y * cos(Rad) + x * sin(Rad);
        new_x += add_width;
        new_y += add_height;
        output_p->data[new_y][new_x].r = picture_p->data[raw_y][raw_x].r;
        output_p->data[new_y][new_x].g = picture_p->data[raw_y][raw_x].g;
        output_p->data[new_y][new_x].b = picture_p->data[raw_y][raw_x].b;
    }
}

int main(int argc, char *argv[]) {
    double deg, rad;
    int add_height, add_width;
    img *picture_p;
    picture_p = (img *)malloc(sizeof(img));
    if (argc != 2) {
        printf("init_CUDA.exe file_name\n");
        exit(0);
    }
    ReadBmp(argv[1], picture_p);

    // 4点を見る
    //(0,0) (0,width) (height,0) (height,width)
    deg = 45.0;
    rad = deg * PI / 180.0;
    int min_height = 1e9;
    int max_height = -1e9;
    int min_width = 1e9;
    int max_width = -1e9;
    int four_check[4][2] = {{0, 0},
                            {0, picture_p->width},
                            {picture_p->height, 0},
                            {picture_p->height, picture_p->width}};
    for (int i = 0; i < 4; i++) {
        int height = four_check[i][0];
        height -= picture_p->height / 2;
        int width = four_check[i][1];
        width -= picture_p->width / 2;
        int new_height = height * cos(rad) + width * sin(rad);
        int new_width = -height * sin(rad) + width * cos(rad);
        if (new_height > max_height) {
            max_height = new_height;
        }
        if (new_height < min_height) {
            min_height = new_height;
        }
        if (new_width > max_width) {
            max_width = new_width;
        }
        if (new_width < min_width) {
            min_width = new_width;
        }
    }
    max_height -= min_height;
    max_width -= min_width;
    add_height = -min_height;
    add_width = -min_width;

    img *output_p;
    output_p = (img *)malloc(sizeof(img));
    output_p->height = max_height;
    output_p->width = max_width;

    img * cuda_output;
    cudaMalloc(&cuda_output,sizeof(img));
    img * cuda_input;
    cudaMalloc(&cuda_input,sizeof(img));
    cudaMemcpy(cuda_input,picture_p,sizeof(img),cudaMemcpyHostToDevice);
    dim3 grid((picture_p->height+BLOCK)/BLOCK, (picture_p->width+BLOCK)/BLOCK,1); 
    dim3 threads(BLOCK,BLOCK,1);
    GPU_process<<<grid,threads>>>(cuda_input,cuda_output,rad,add_width,add_height,picture_p->height,picture_p->width);

    printf("end\n");
    cudaMemcpy(output_p,cuda_output,sizeof(img),cudaMemcpyDeviceToHost);
    cudaFree(cuda_output);
    output_p->height=max_height;
    output_p->width=max_width;
    /*
    for (double Deg = 0; Deg < 360; Deg++) {
        double Rad = Deg * PI / 180.0;
        for (int raw_y = 0; raw_y < picture_p->height; raw_y++) {
            for (int raw_x = 0; raw_x < picture_p->width; raw_x++) {
                int x = raw_x - picture_p->width / 2;
                int y = raw_y - picture_p->height / 2;
                int new_x = -x * cos(Rad) + y * sin(Rad);
                int new_y = y * cos(Rad) + x * sin(Rad);
                new_x += add_width;
                new_y += add_height;
                if (new_x < 0) new_x = 0;
                if (new_y < 0) new_y = 0;
                output_p->data[new_y][new_x].r =
                    picture_p->data[raw_y][raw_x].r;
                output_p->data[new_y][new_x].g =
                    picture_p->data[raw_y][raw_x].g;
                output_p->data[new_y][new_x].b =
                    picture_p->data[raw_y][raw_x].b;
            }
        }
    }*/
    WriteBmp("CUDA_output/gpu_output4.bmp", output_p);
    free(output_p);
    return 0;
}
