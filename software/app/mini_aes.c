#include <hf-risc.h>

#define AES_BASE			0xe7000000
#define AES_CONTROL			(*(volatile uint32_t *)(AES_BASE + 0x000))
#define AES_KEY0			(*(volatile uint32_t *)(AES_BASE + 0x010))
#define AES_KEY1			(*(volatile uint32_t *)(AES_BASE + 0x020))
#define AES_KEY2			(*(volatile uint32_t *)(AES_BASE + 0x030))
#define AES_KEY3			(*(volatile uint32_t *)(AES_BASE + 0x040))
#define AES_IN0				(*(volatile uint32_t *)(AES_BASE + 0x050))
#define AES_IN1				(*(volatile uint32_t *)(AES_BASE + 0x060))
#define AES_IN2				(*(volatile uint32_t *)(AES_BASE + 0x070))
#define AES_IN3				(*(volatile uint32_t *)(AES_BASE + 0x080))
#define AES_OUT0			(*(volatile uint32_t *)(AES_BASE + 0x090))
#define AES_OUT1			(*(volatile uint32_t *)(AES_BASE + 0x0A0))
#define AES_OUT2			(*(volatile uint32_t *)(AES_BASE + 0x0B0))
#define AES_OUT3			(*(volatile uint32_t *)(AES_BASE + 0x0C0))
#define AES_LOAD			(1 << 0)
#define AES_ENCRYPT			(0 << 1)
#define AES_DECRYPT			(1 << 1)
#define AES_DONE			(1 << 2)
#define AES_SIZE			4

/* constantes */
const uint32_t   key_in[AES_SIZE] = {  0x00010203, 0x05060708, 0x0A0B0C0D, 0x0F101112 };
const uint32_t  data_in[AES_SIZE] = {  0x506812A4, 0x5F08C889, 0xB97F5980, 0x038B8359 };
const uint32_t  enc_out[AES_SIZE] = {  0xD8F53253, 0x8289EF7D, 0x06B506A4, 0xFD5BE9C9 };
const uint32_t  dec_out[AES_SIZE] = {  0x3553EE25, 0xE8128DC0, 0xF175765D, 0x6E5BE9C9 };

/* prototipos */
void aes_hw_setkey(uint32_t key_i[AES_SIZE]);
void aes_hw_cipher(uint32_t data_i[AES_SIZE], uint8_t oper);
void aes_hw_encipher(uint32_t data_i[AES_SIZE]);
void aes_hw_decipher(uint32_t data_i[AES_SIZE]);
void aes_ctr_crypt(uint8_t *out, uint8_t *in, uint32_t len, const uint32_t key[AES_SIZE], const uint32_t nonce[AES_SIZE]);


int main(void) 
{	
	return 0;
}

void aes_hw_setkey(uint32_t key_i[AES_SIZE])
{
	AES_KEY0 = key_i[0];
	AES_KEY1 = key_i[1];
	AES_KEY2 = key_i[2];
	AES_KEY3 = key_i[3];
}

void aes_hw_cipher(uint32_t data_i[AES_SIZE], uint8_t oper)
{
	AES_CONTROL = oper;
	AES_IN0 = data_i[0];
	AES_IN1 = data_i[1];
	AES_IN2 = data_i[2];
	AES_IN3 = data_i[3];
	
	AES_CONTROL |= AES_LOAD;
	while (!(AES_CONTROL & ~AES_LOAD));
	
	while (!(AES_CONTROL & AES_DONE));
	data_i[0] = AES_OUT0;
	data_i[1] = AES_OUT1;
	data_i[2] = AES_OUT2;
	data_i[3] = AES_OUT3;
}

void aes_hw_encipher(uint32_t data_i[AES_SIZE])
{
	AES_CONTROL = AES_ENCRYPT;
	AES_IN0 = data_i[0];
	AES_IN1 = data_i[1];
	AES_IN2 = data_i[2];
	AES_IN3 = data_i[3];
	
	AES_CONTROL |= AES_LOAD;
	while (!(AES_CONTROL & ~AES_LOAD));
	
	while (!(AES_CONTROL & AES_DONE));
	data_i[0] = AES_OUT0;
	data_i[1] = AES_OUT1;
	data_i[2] = AES_OUT2;
	data_i[3] = AES_OUT3;
}

void aes_hw_decipher(uint32_t data_i[AES_SIZE])
{
	AES_CONTROL = AES_DECRYPT;
	AES_IN0 = data_i[0];
	AES_IN1 = data_i[1];
	AES_IN2 = data_i[2];
	AES_IN3 = data_i[3];
	
	AES_CONTROL |= AES_LOAD;
	while (!(AES_CONTROL & ~AES_LOAD));
	
	while (!(AES_CONTROL & AES_DONE));
	data_i[0] = AES_OUT0;
	data_i[1] = AES_OUT1;
	data_i[2] = AES_OUT2;
	data_i[3] = AES_OUT3;
}
