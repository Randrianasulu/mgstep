// Next to Unicode maping
const unsigned int NeXT_conv_base = 0x80;

unichar NeXT_char_to_unichar_table[] =
{
  0x00A0,
  0x00C0,
  0x00C1,
  0x00C2,
  0x00C3,
  0x00C4,
  0x00C5,
  0x00C7,
  0x00C8,
  0x00C9,
  0x00CA,
  0x00CB,
  0x00CC,
  0x00CD,
  0x00CE,
  0x00CF,
  0x00D0,
  0x00D1,
  0x00D2,
  0x00D3,
  0x00D4,
  0x00D5,
  0x00D6,
  0x00D9,
  0x00DA,
  0x00DB,
  0x00DC,
  0x00DD,
  0x00DE,
  0x00B5,
  0x00D7,
  0x00F7,
  0x00A9,
  0x00A1,
  0x00A2,
  0x00A3,
  0x2044,
  0x00A5,
  0x0192,
  0x00A7,
  0x00A4,
  0x201C,
  0x00AB,
  0xFB01,
  0xFB02,
  0x00AE,
  0x2013,
  0x2020,
  0x2021,
  0x00B7,
  0x00A6,
  0x00B6,
  0x2022,
  0x201D,
  0x00BB,
  0x2026,
  0x2030,
  0x00AC,
  0x00BF,
  0x00B9,
  0x02CB,
  0x00B4,
  0x02C6,
  0x02DC,
  0x00AF,
  0x02D8,
  0x02D9,
  0x00A8,
  0x00B2,
  0x02DA,
  0x00B8,
  0x00B3,
  0x02DD,
  0x02DB,
  0x02C7,
  0x2014,
  0x00B1,
  0x00BC,
  0x00BD,
  0x00BE,
  0x00E0,
  0x00E1,
  0x00E2,
  0x00E3,
  0x00E4,
  0x00E5,
  0x00E7,
  0x00E8,
  0x00E9,
  0x00EA,
  0x00EB,
  0x00EC,
  0x00C6,
  0x00ED,
  0x00AA,
  0x00EE,
  0x00EF,
  0x00F0,
  0x00F1,
  0x0141,
  0x00D8,
  0x0152,
  0x00BA,
  0x00F2,
  0x00F3,
  0x00F4,
  0x00F5,
  0x00F6,
  0x00E6,
  0x00F9,
  0x00FA,
  0x00FB,
  0x0131,
  0x00FC,
  0x00FD,
  0x0142,
  0x00F8,
  0x0153,
  0x00DF,
  0x00FE,
  0x00FF,
};

// Unicode to NextStep maping

const unsigned int NeXT_uni_to_char_table_size = 128;

struct _ucc_ { unichar from; char to; };

struct _ucc_ NeXT_unichar_to_char_table[]=
{
  {0x00A0,0x80},
  {0x00A1,0xA1},
  {0x00A2,0xA2},
  {0x00A3,0xA3},
  {0x00A4,0xA8},
  {0x00A5,0xA5},
  {0x00A6,0xB5},
  {0x00A7,0xA7},
  {0x00A8,0xC8},
  {0x00A9,0xA0},
  {0x00AA,0xE3},
  {0x00AB,0xAB},
  {0x00AC,0xBE},
  {0x00AE,0xB0},
  {0x00AF,0xC5},
  {0x00B1,0xD1},
  {0x00B2,0xC9},
  {0x00B3,0xCC},
  {0x00B4,0xC2},
  {0x00B5,0x9D},
  {0x00B6,0xB6},
  {0x00B7,0xB4},
  {0x00B8,0xCB},
  {0x00B9,0xC0},
  {0x00BA,0xEB},
  {0x00BB,0xBB},
  {0x00BC,0xD2},
  {0x00BD,0xD3},
  {0x00BE,0xD4},
  {0x00BF,0xBF},
  {0x00C0,0x81},
  {0x00C1,0x82},
  {0x00C2,0x83},
  {0x00C3,0x84},
  {0x00C4,0x85},
  {0x00C5,0x86},
  {0x00C6,0xE1},
  {0x00C7,0x87},
  {0x00C8,0x88},
  {0x00C9,0x89},
  {0x00CA,0x8A},
  {0x00CB,0x8B},
  {0x00CC,0x8C},
  {0x00CD,0x8D},
  {0x00CE,0x8E},
  {0x00CF,0x8F},
  {0x00D0,0x90},
  {0x00D1,0x91},
  {0x00D2,0x92},
  {0x00D3,0x93},
  {0x00D4,0x94},
  {0x00D5,0x95},
  {0x00D6,0x96},
  {0x00D7,0x9E},
  {0x00D8,0xE9},
  {0x00D9,0x97},
  {0x00DA,0x98},
  {0x00DB,0x99},
  {0x00DC,0x9A},
  {0x00DD,0x9B},
  {0x00DE,0x9C},
  {0x00DF,0xFB},
  {0x00E0,0xD5},
  {0x00E1,0xD6},
  {0x00E2,0xD7},
  {0x00E3,0xD8},
  {0x00E4,0xD9},
  {0x00E5,0xDA},
  {0x00E6,0xF1},
  {0x00E7,0xDB},
  {0x00E8,0xDC},
  {0x00E9,0xDD},
  {0x00EA,0xDE},
  {0x00EB,0xDF},
  {0x00EC,0xE0},
  {0x00ED,0xE2},
  {0x00EE,0xE4},
  {0x00EF,0xE5},
  {0x00F0,0xE6},
  {0x00F1,0xE7},
  {0x00F2,0xEC},
  {0x00F3,0xED},
  {0x00F4,0xEE},
  {0x00F5,0xEF},
  {0x00F6,0xF0},
  {0x00F7,0x9F},
  {0x00F8,0xF9},
  {0x00F9,0xF2},
  {0x00FA,0xF3},
  {0x00FB,0xF4},
  {0x00FC,0xF6},
  {0x00FD,0xF7},
  {0x00FE,0xFC},
  {0x00FF,0xFD},
  {0x0131,0xF5},
  {0x0141,0xE8},
  {0x0142,0xF8},
  {0x0152,0xEA},
  {0x0153,0xFA},
  {0x0192,0xA6},
  {0x02C6,0xC3},
  {0x02C7,0xCF},
  {0x02CB,0xC1},
  {0x02D8,0xC6},
  {0x02D9,0xC7},
  {0x02DA,0xCA},
  {0x02DB,0xCE},
  {0x02DC,0xC4},
  {0x02DD,0xCD},
  {0x2013,0xB1},
  {0x2014,0xD0},
  {0x201C,0xAA},
  {0x201D,0xBA},
  {0x2020,0xB2},
  {0x2021,0xB3},
  {0x2022,0xB7},
  {0x2026,0xBC},
  {0x2030,0xBD},
  {0x2044,0xA4},
  {0xFB01,0xAE},
  {0xFB02,0xAF},
};
