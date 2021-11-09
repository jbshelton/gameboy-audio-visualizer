#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <unistd.h> 

/*
    Higher range pulse/DAC values?
    n*17 where n is 0 to 15
    n in this case will initially be only 0 to 7 because of LUT generation method
    Negative (n = 0 to 7):
    pulse = 7-p
    pulse = (pulse*17)+1
    outamp = (pulse*(m+1))-1
    Positive (n = 8 to 15):
    pulse = p+8
    pulse = (pulse*17)+1

    output range is 11-bit
*/

struct hq_lut_t
{
    uint8_t pulse_lut[2048];
    uint8_t mv_lut[2048];
    int amp_lut[2048];
    bool is_unique[2048];
};

struct shq_lut_t
{
    uint8_t pulse_lut[4096][9];
    uint8_t mv_lut[4096][9];
    uint8_t nw_lut[4096][9];
    int amp_lut[4096];
    int repeats[4096];
    int prev_index;
    int prev_amp;
    int max_repeats;
    int max_index;
};

void init_hq_lut(struct hq_lut_t *hq_lut)
{
    for(int i=0; i<2048; i++)
    {
        hq_lut->pulse_lut[i] = 0;
        hq_lut->mv_lut[i] = 0;
        hq_lut->amp_lut[i] = -1;
        hq_lut->is_unique[i] = false;
    }
}

void init_shq_lut(struct shq_lut_t *shq_lut)
{
    for(int j=0; j<10; j++)
    {
    for(int i=0; i<4096; i++)
    {
        shq_lut->pulse_lut[i][j] = 0;
        shq_lut->mv_lut[i][j] = 0;
        shq_lut->nw_lut[i][j] = 0;
        shq_lut->amp_lut[i] = -1;
        shq_lut->repeats[i] = 0;
        shq_lut->prev_index = 0;
        shq_lut->prev_amp = 0;
    }
    }
}

uint16_t hq_calculate_outamp(uint8_t write_val)
{
    uint8_t p = (write_val&0xf0)>>4;
    uint8_t m = write_val&0x0f;
    int pulse = 0;
    int outamp = 0;
    pulse = (p*17)+1;
    outamp = (pulse*((int)m+1))-1;
    return outamp;
}

void generate_hq_lut(struct hq_lut_t *hq_lut)
{
    init_hq_lut(hq_lut);
    
    int pulse = 0;
    int uniqueamps = 0;
    int outamp = 0;

    for(int m=0; m<8; m++)
    {
        for(int p=0; p<8; p++)
        {
            pulse = 7-p;
            pulse = (pulse*17)-128; //ranges from -9 to -128
            outamp = (pulse*((int)m+1))+1024; //now from 0 to 952

            if(hq_lut->amp_lut[outamp]==-1)
            {   
                uniqueamps++;
                hq_lut->pulse_lut[outamp] = (uint8_t)(7-p);
                hq_lut->mv_lut[outamp] = (uint8_t)m;
                hq_lut->amp_lut[outamp] = outamp;
                hq_lut->is_unique[outamp] = true;
            }

            pulse = p+8;
            pulse = (pulse*17)-127; //ranges from 9 to 128
            outamp = (pulse*((int)m+1))+1023; //now from 1095 to 2047

            if(hq_lut->amp_lut[outamp]==-1)
            {   
                uniqueamps++;
                hq_lut->pulse_lut[outamp] = (uint8_t)(p+8);
                hq_lut->mv_lut[outamp] = (uint8_t)m;
                hq_lut->amp_lut[outamp] = outamp;
                hq_lut->is_unique[outamp] = true;
            }
        }
    }

    printf("no. of unique amplitudes (hq) = %d\n", uniqueamps);
    uint8_t temp_mv, temp_pulse;
    temp_pulse = 0;
    temp_mv = 0;
    int temp_amp;
    temp_amp = 0;

    for(int i=0; i<1024; i++)
    {
        if(hq_lut->amp_lut[i]==i)
        {
            temp_pulse = hq_lut->pulse_lut[i];
            temp_mv = hq_lut->mv_lut[i];
            temp_amp = hq_lut->amp_lut[i];
        }
        else
        {
            hq_lut->pulse_lut[i] = temp_pulse;
            hq_lut->mv_lut[i] = temp_mv;
            hq_lut->amp_lut[i] = temp_amp;
        }
    }

    for(int i=2047; i>=1024; i--)
    {
        if(hq_lut->amp_lut[i]==i)
        {
            temp_pulse = hq_lut->pulse_lut[i];
            temp_mv = hq_lut->mv_lut[i];
            temp_amp = hq_lut->amp_lut[i];
        }
        else
        {
            hq_lut->pulse_lut[i] = temp_pulse;
            hq_lut->mv_lut[i] = temp_mv;
            hq_lut->amp_lut[i] = temp_amp;
        }
    }
}

void generate_shq_lut(struct shq_lut_t *shq_lut)
{
    init_shq_lut(shq_lut);
    
    int pulse = 0;
    int noisewave = 0;
    int uniqueamps = 0;
    int outamp = 0;

    for(int nw=0; nw<3; nw++)
    {
        for(int m=0; m<8; m++)
        {
            for(int p=0; p<8; p++)
            {
                //revised version:
                //noisewave either equals -128 or 128 because of new algorithm
                //old version:
                //noisewave either equals -15 or 15
                if(nw==0)
                {
                    noisewave = 0;
                }
                else if(nw==1)
                {
                    noisewave = 128;
                }
                else
                {
                    noisewave = -128;
                }

                //new version: p is from 0 to 7
                pulse = 7-p;
                pulse = (pulse*17)-128; //ranges from -9 to -128, minus noisewave is -256
                outamp = ((pulse+noisewave)*((int)m+1))+2048;

                if(shq_lut->amp_lut[outamp]==-1)
                {   
                    uniqueamps++;
                    shq_lut->pulse_lut[outamp][shq_lut->repeats[outamp]] = (uint8_t)p;
                    shq_lut->mv_lut[outamp][shq_lut->repeats[outamp]] = (uint8_t)m;
                    shq_lut->nw_lut[outamp][shq_lut->repeats[outamp]] = (((uint8_t)nw)<<2);
                    shq_lut->amp_lut[outamp] = outamp;
                }
                else
                {
                    shq_lut->repeats[outamp]++;
                    shq_lut->pulse_lut[outamp][shq_lut->repeats[outamp]] = (uint8_t)p;
                    shq_lut->mv_lut[outamp][shq_lut->repeats[outamp]] = (uint8_t)m;
                    shq_lut->nw_lut[outamp][shq_lut->repeats[outamp]] = (((uint8_t)nw)<<2);
                }

                pulse = p+8;
                pulse = (pulse*17)-127; //ranges from 9 to 128
                outamp = ((pulse+noisewave)*((int)m+1))+2047;

                if(shq_lut->amp_lut[outamp]==-1)
                {   
                    uniqueamps++;
                    shq_lut->pulse_lut[outamp][shq_lut->repeats[outamp]] = (uint8_t)p;
                    shq_lut->mv_lut[outamp][shq_lut->repeats[outamp]] = (uint8_t)m;
                    shq_lut->nw_lut[outamp][shq_lut->repeats[outamp]] = (((uint8_t)nw)<<2);
                    shq_lut->amp_lut[outamp] = outamp;
                }
                else
                {
                    shq_lut->repeats[outamp]++;
                    shq_lut->pulse_lut[outamp][shq_lut->repeats[outamp]] = (uint8_t)p;
                    shq_lut->mv_lut[outamp][shq_lut->repeats[outamp]] = (uint8_t)m;
                    shq_lut->nw_lut[outamp][shq_lut->repeats[outamp]] = (((uint8_t)nw)<<2);
                }
            }
        }
    }

    printf("no. of unique amplitudes (shq) = %d\n", uniqueamps);
    int max_repeats = 0;
    for(int i=0; i<4096; i++)
    {
        if(shq_lut->repeats[i]>max_repeats)
        {
            max_repeats = shq_lut->repeats[i];
            shq_lut->max_index = i;
        }
    }
    printf("no. of max combination repeats = %d\n", max_repeats);
    shq_lut->max_repeats = max_repeats;

    uint8_t temp_mv, temp_pulse, temp_nw;
    temp_pulse = 0;
    temp_mv = 0;
    temp_nw = 0;
    int temp_amp = 0;

    for(int j=0; j<max_repeats; j++)
    {
    for(size_t i=0; i<2048; i++)
    {
        if(shq_lut->amp_lut[i]!=-1)
        {
            temp_pulse = shq_lut->pulse_lut[i][j];
            temp_mv = shq_lut->mv_lut[i][j];
            temp_nw = shq_lut->nw_lut[i][j];
            temp_amp = shq_lut->amp_lut[i];
        }
        else
        {
            shq_lut->pulse_lut[i][j] = temp_pulse;
            shq_lut->mv_lut[i][j] = temp_mv;
            shq_lut->nw_lut[i][j] = temp_nw;
            shq_lut->amp_lut[i] = temp_amp;
        }
    }

    for(size_t i=2047; i>0; i--)
    {
        if(shq_lut->amp_lut[i]!=-1)
        {
            temp_pulse = shq_lut->pulse_lut[i][j];
            temp_mv = shq_lut->mv_lut[i][j];
            temp_nw = shq_lut->nw_lut[i][j];
            temp_amp = shq_lut->amp_lut[i];
        }
        else
        {
            shq_lut->pulse_lut[i][j] = temp_pulse;
            shq_lut->mv_lut[i][j] = temp_mv;
            shq_lut->nw_lut[i][j] = temp_nw;
            shq_lut->amp_lut[i] = temp_amp;
        }
    }

    for(size_t i=4095; i>=2048; i--)
    {
        if(shq_lut->amp_lut[i]!=-1)
        {
            temp_pulse = shq_lut->pulse_lut[i][j];
            temp_mv = shq_lut->mv_lut[i][j];
            temp_nw = shq_lut->nw_lut[i][j];
            temp_amp = shq_lut->amp_lut[i];
        }
        else
        {
            shq_lut->pulse_lut[i][j] = temp_pulse;
            shq_lut->mv_lut[i][j] = temp_mv;
            shq_lut->nw_lut[i][j] = temp_nw;
            shq_lut->amp_lut[i] = temp_amp;
        }
    }

    for(size_t i=2048; i<4095; i++)
    {
        if(shq_lut->amp_lut[i]!=-1)
        {
            temp_pulse = shq_lut->pulse_lut[i][j];
            temp_mv = shq_lut->mv_lut[i][j];
            temp_nw = shq_lut->nw_lut[i][j];
            temp_amp = shq_lut->amp_lut[i];
        }
        else
        {
            shq_lut->pulse_lut[i][j] = temp_pulse;
            shq_lut->mv_lut[i][j] = temp_mv;
            shq_lut->nw_lut[i][j] = temp_nw;
            shq_lut->amp_lut[i] = temp_amp;
        }
    }
    }
}


int main(int argc, const char * argv[])
{
	struct hq_lut_t *hq_lut = (struct hq_lut_t *)(malloc(sizeof(struct hq_lut_t)));
    struct shq_lut_t *shq_lut = (struct shq_lut_t *)(malloc(sizeof(struct shq_lut_t)));
    generate_hq_lut(hq_lut);
    generate_shq_lut(shq_lut);
    free(hq_lut);
    free(shq_lut);

    //FILE *amp_lut = fopen("amp_lut.bin", "wb");
    //FILE *stereo_lut = fopen("scx_lut_stereo.bin", "wb");
    //FILE *mono_lut = fopen("scx_lut_mono.bin", "wb");
    //FILE *ly_lut = fopen("lyc_lut.bin", "wb");
    //uint8_t outamp_lut[512];
    //uint8_t lut_outamp = 0;
    //uint8_t scx_lut_stereo[512];
    //uint8_t scx_lut_mono[256];
    //uint8_t lyc_lut[256];
    //uint8_t outamp = 0;
    //int scx_index = 0;
    //int lut_index = 0;
    //uint8_t sign = 0;
    /*
    for(uint16_t i=0; i<512; i++)
    {
        if(i<256)
        {    
            //lut_outamp = (hq_lut->pulse_lut[i]<<4)|hq_lut->mv_lut[i];
            outamp = hq_calculate_outamp((uint8_t)i);
            scx_lut_mono[i] = ~((outamp>>1)+8);
            scx_lut_stereo[i] = ~(outamp>>2);
            if(i<153)
            {
                lyc_lut[i] = i+1;
            }
            else
            {
                lyc_lut[i] = i-153;
            }
        }
        else
        {
        	//lut_outamp = (hq_lut->pulse_lut[i-256]<<4)|hq_lut->mv_lut[i-256];
            outamp = hq_calculate_outamp((uint8_t)(i-256));
            scx_lut_stereo[i] = (outamp>>2)+87;
        }
    }
    */
    //lut_outamp = (hq_lut->pulse_lut[255]<<4)|hq_lut->mv_lut[255];
    //scx_lut[lut_outamp] = 127;
    /*
    for(signed char i=-128; i<127; i++)
    {
        outamp_lut[lut_index++] = (hq_lut->mv_lut[(int)i+128]<<4)|hq_lut->mv_lut[i+128];
    }
    spr_lut[sprite_index++] = 127+124;
    */
    /*
    fwrite(scx_lut_stereo, 1, 512, stereo_lut);
    fclose(stereo_lut);
    fwrite(scx_lut_mono, 1, 256, mono_lut);
    fclose(mono_lut);
    fwrite(lyc_lut, 1, 256, ly_lut);
    fclose(ly_lut);
    */
    //fwrite(outamp_lut, 1, 512, amp_lut);
    //fclose(amp_lut);
    //free(hq_lut);
}