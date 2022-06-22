#include <hf-risc.h>

#define TEST				1

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
#define AES_LOAD			(1 << 3)
#define AES_ENCRYPT			(0 << 1)
#define AES_DECRYPT			(1 << 1)
#define AES_DONE			(1 << 2)
#define AES_START			(1 << 3)
#define AES_SIZE			4

/* constantes */
const uint32_t 	     iv[AES_SIZE] = { 0x14151617, 0x191A1B1C, 0x1E1F2021, 0x23242526 };
const uint32_t   key_in[AES_SIZE] = { 0x00010203, 0x05060708, 0x0A0B0C0D, 0x0F101112 };
#if TEST
// #define TEST_SIZE 		4
// const uint32_t data_in[TEST_SIZE] = { 0x506812A4, 0x5F08C889, 0xB97F5980, 0x038B8359 };
#define TEST_SIZE			16
const uint32_t  data_in[TEST_SIZE] = { 
	0x506812A4, 0x5F08C889, 0xB97F5980, 0x038B8359,
	0x038B8359, 0x506812A4, 0x5F08C889, 0xB97F5980,
	0xB97F5980, 0x038B8359, 0x506812A4, 0x5F08C889,
	0x5F08C889, 0xB97F5980, 0x038B8359, 0x506812A4
};
#else
#define TEST_SIZE			96
const uint32_t  data_in[TEST_SIZE] = { 
	0x506812A4, 0x5F08C889, 0xB97F5980, 0x038B8359,
	0x038B8359, 0x506812A4, 0x5F08C889, 0xB97F5980,
	0xB97F5980, 0x038B8359, 0x506812A4, 0x5F08C889,
	0x5F08C889, 0xB97F5980, 0x038B8359, 0x506812A4,
	0x5C6D71CA, 0x30DE8B8B, 0x00549984, 0xD2EC7D4B,
	0xD2EC7D4B, 0x5C6D71CA, 0x30DE8B8B, 0x00549984,
	0x00549984, 0xD2EC7D4B, 0x5C6D71CA, 0x30DE8B8B,
	0x30DE8B8B, 0x00549984, 0xD2EC7D4B, 0x5C6D71CA,
	0X53F3F4C6, 0X4F8616E4, 0XE7C56199, 0XF48F21F6,
	0XF48F21F6, 0X53F3F4C6, 0X4F8616E4, 0XE7C56199,
	0XE7C56199, 0XF48F21F6, 0X53F3F4C6, 0X4F8616E4,
	0X4F8616E4, 0XE7C56199, 0XF48F21F6, 0X53F3F4C6,
	0XA1EB65A3, 0X487165FB, 0X0F1C27FF, 0X9959F703,
	0X9959F703, 0XA1EB65A3, 0X487165FB, 0X0F1C27FF,
	0X0F1C27FF, 0X9959F703, 0XA1EB65A3, 0X487165FB,
	0X487165FB, 0X0F1C27FF, 0X9959F703, 0XA1EB65A3,
	0X3553ECF0, 0XB1739558, 0XB08E350A, 0X98A39BFA,
	0X98A39BFA, 0X3553ECF0, 0XB1739558, 0XB08E350A,
	0XB08E350A, 0X98A39BFA, 0X3553ECF0, 0XB1739558,
	0XB1739558, 0XB08E350A, 0X98A39BFA, 0X3553ECF0,
	0X67429969, 0X490B9711, 0XAE2B01DC, 0X497AFDE8,
	0X497AFDE8, 0X67429969, 0X490B9711, 0XAE2B01DC,
	0XAE2B01DC, 0X497AFDE8, 0X67429969, 0X490B9711,
	0X490B9711, 0XAE2B01DC, 0X497AFDE8, 0X67429969
};
#endif

/* prototipos */
void aes_hw_setkey(const uint32_t key[AES_SIZE]);
void aes_hw_encipher(uint32_t data[AES_SIZE]);
void aes_hw_decipher(uint32_t data[AES_SIZE]);
void aes_ecb_encipher(uint32_t *out, uint32_t *in, uint32_t len);
void aes_ecb_decipher(uint32_t *out, uint32_t *in, uint32_t len);
void aes_cbc_encipher(uint32_t *out, uint32_t *in, uint32_t len);
void aes_cbc_decipher(uint32_t *out, uint32_t *in, uint32_t len);

int main(void) 
{
	uint32_t message[TEST_SIZE];
	aes_hw_setkey(key_in);

	memcpy(message, data_in, (TEST_SIZE * sizeof(uint32_t)));
	aes_ecb_encipher(message, message, TEST_SIZE);
	// printf("\n-------------------------------------\n");
	aes_ecb_decipher(message, message, TEST_SIZE);
	
	return 0;
}

/* funcoes */
void aes_hw_setkey(const uint32_t key[AES_SIZE])
{
	AES_KEY0 = key[0];
	AES_KEY1 = key[1];
	AES_KEY2 = key[2];
	AES_KEY3 = key[3];
}
void aes_hw_encipher(uint32_t data[AES_SIZE])
{
	AES_CONTROL = AES_ENCRYPT;
	AES_IN0 = data[0];
	AES_IN1 = data[1];
	AES_IN2 = data[2];
	AES_IN3 = data[3];

	AES_CONTROL |= AES_START;
	while (!(AES_CONTROL & AES_DONE));
	AES_CONTROL &= ~AES_START;
	
	data[0] = AES_OUT0;
	data[1] = AES_OUT1;
	data[2] = AES_OUT2;
	data[3] = AES_OUT3;	
}
void aes_hw_decipher(uint32_t data[AES_SIZE])
{
	AES_CONTROL = AES_DECRYPT;
	AES_IN0 = data[0];
	AES_IN1 = data[1];
	AES_IN2 = data[2];
	AES_IN3 = data[3];

	AES_CONTROL |= AES_START;
	while (!(AES_CONTROL & AES_DONE));
	AES_CONTROL &= ~AES_START;
	
	data[0] = AES_OUT0;
	data[1] = AES_OUT1;
	data[2] = AES_OUT2;
	data[3] = AES_OUT3;
}
void aes_ecb_encipher(uint32_t *out, uint32_t *in, uint32_t len)
{
	uint32_t i, rem, block[AES_SIZE];
	
	rem = len % AES_SIZE;
	for (i = 0; i < len; i += AES_SIZE) {
		aes_hw_encipher(in);
		in += AES_SIZE;
		out += AES_SIZE;
	}
	if (rem) {
		memcpy(block, in, AES_SIZE);
		memcpy(block, in, AES_SIZE - rem);
		memset(block + rem, 0, AES_SIZE - rem);
		aes_hw_encipher(in);
		memcpy(out, block, AES_SIZE - rem);
	}
}
void aes_ecb_decipher(uint32_t *out, uint32_t *in, uint32_t len)
{
	uint32_t i, rem, block[AES_SIZE];
	
	rem = len % AES_SIZE;
	for (i = 0; i < len; i += AES_SIZE) {
		aes_hw_decipher(in);
		in += AES_SIZE;
		out += AES_SIZE;
	}
	if (rem) {
		memcpy(block, in, AES_SIZE);
		memcpy(block, in, AES_SIZE - rem);
		memset(block + rem, 0, AES_SIZE - rem);
		aes_hw_decipher(block);
		memcpy(out, block, AES_SIZE - rem);
	}
}
void aes_cbc_encipher(uint32_t *out, uint32_t *in, uint32_t len)
{
	uint32_t i, rem, block[AES_SIZE], tiv[AES_SIZE];
	
	rem = len % AES_SIZE;
	tiv[0] = iv[0];
	tiv[1] = iv[1];
	tiv[2] = iv[2];
	tiv[3] = iv[3];
	for (i = 0; i < len; i += AES_SIZE) {
		in[0] ^= tiv[0];
		in[1] ^= tiv[1];
		in[2] ^= tiv[2];
		in[3] ^= tiv[3];
		aes_hw_encipher(in);
		tiv[0] = out[0];
		tiv[1] = out[1];
		tiv[2] = out[2];
		tiv[3] = out[3];
		in += AES_SIZE;
		out += AES_SIZE;
	}
	if (rem) {
		memcpy(block, in, AES_SIZE);
		memcpy(block, in, AES_SIZE - rem);
		memset(block + rem, 0, AES_SIZE - rem);
		block[0] ^= tiv[0];
		block[1] ^= tiv[1];
		block[2] ^= tiv[2];
		block[3] ^= tiv[3];
		aes_hw_encipher(block);
		memcpy(out, block, AES_SIZE - rem);
	}
}
void aes_cbc_decipher(uint32_t *out, uint32_t *in, uint32_t len)
{
	uint32_t i, rem, block[AES_SIZE], tiv[AES_SIZE];
	
	rem = len % AES_SIZE;
	tiv[0] = iv[0];
	tiv[1] = iv[1];
	tiv[2] = iv[2];
	tiv[3] = iv[3];
	for (i = 0; i < len; i += AES_SIZE) {

		in[0] ^= tiv[0];
		in[1] ^= tiv[1];
		in[2] ^= tiv[2];
		in[3] ^= tiv[3];
		aes_hw_decipher(in);
		out[0] = block[0];
		out[1] = block[1];
		out[2] = block[2];
		out[3] = block[3];
		in += AES_SIZE;
		out += AES_SIZE;
	}
	if (rem) {
		memcpy(block, in, AES_SIZE);
		memcpy(block, in, AES_SIZE - rem);
		memset(block + rem, 0, AES_SIZE - rem);
		block[0] ^= tiv[0];
		block[1] ^= tiv[1];
		block[2] ^= tiv[2];
		block[3] ^= tiv[3];
		aes_hw_decipher(block);
		memcpy(out, block, AES_SIZE - rem);
	}
}
