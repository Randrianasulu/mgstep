int t_len_tolower=388;

int t_len_toupper=389;

unichar t_tolower[][2]=
{
  {0x0041,0x0061},
  {0x0042,0x0062},
  {0x0043,0x0063},
  {0x0044,0x0064},
  {0x0045,0x0065},
  {0x0046,0x0066},
  {0x0047,0x0067},
  {0x0048,0x0068},
  {0x0049,0x0069},
  {0x004a,0x006a},
  {0x004b,0x006b},
  {0x004c,0x006c},
  {0x004d,0x006d},
  {0x004e,0x006e},
  {0x004f,0x006f},
  {0x0050,0x0070},
  {0x0051,0x0071},
  {0x0052,0x0072},
  {0x0053,0x0073},
  {0x0054,0x0074},
  {0x0055,0x0075},
  {0x0056,0x0076},
  {0x0057,0x0077},
  {0x0058,0x0078},
  {0x0059,0x0079},
  {0x005a,0x007a},
  {0x00c0,0x00e0},
  {0x00c1,0x00e1},
  {0x00c2,0x00e2},
  {0x00c3,0x00e3},
  {0x00c4,0x00e4},
  {0x00c5,0x00e5},
  {0x00c6,0x00e6},
  {0x00c7,0x00e7},
  {0x00c8,0x00e8},
  {0x00c9,0x00e9},
  {0x00ca,0x00ea},
  {0x00cb,0x00eb},
  {0x00cc,0x00ec},
  {0x00cd,0x00ed},
  {0x00ce,0x00ee},
  {0x00cf,0x00ef},
  {0x00d0,0x00f0},
  {0x00d1,0x00f1},
  {0x00d2,0x00f2},
  {0x00d3,0x00f3},
  {0x00d4,0x00f4},
  {0x00d5,0x00f5},
  {0x00d6,0x00f6},
  {0x00d8,0x00f8},
  {0x00d9,0x00f9},
  {0x00da,0x00fa},
  {0x00db,0x00fb},
  {0x00dc,0x00fc},
  {0x00dd,0x00fd},
  {0x00de,0x00fe},
  {0x0100,0x0101},
  {0x0102,0x0103},
  {0x0104,0x0105},
  {0x0106,0x0107},
  {0x0108,0x0109},
  {0x010a,0x010b},
  {0x010c,0x010d},
  {0x010e,0x010f},
  {0x0110,0x0111},
  {0x0112,0x0113},
  {0x0114,0x0115},
  {0x0116,0x0117},
  {0x0118,0x0119},
  {0x011a,0x011b},
  {0x011c,0x011d},
  {0x011e,0x011f},
  {0x0120,0x0121},
  {0x0122,0x0123},
  {0x0124,0x0125},
  {0x0126,0x0127},
  {0x0128,0x0129},
  {0x012a,0x012b},
  {0x012c,0x012d},
  {0x012e,0x012f},
  {0x0130,0x0131},
  {0x0132,0x0133},
  {0x0134,0x0135},
  {0x0136,0x0137},
  {0x0139,0x013a},
  {0x013b,0x013c},
  {0x013d,0x013e},
  {0x013f,0x0140},
  {0x0141,0x0142},
  {0x0143,0x0144},
  {0x0145,0x0146},
  {0x0147,0x0148},
  {0x014a,0x014b},
  {0x014c,0x014d},
  {0x014e,0x014f},
  {0x0150,0x0151},
  {0x0152,0x0153},
  {0x0154,0x0155},
  {0x0156,0x0157},
  {0x0158,0x0159},
  {0x015a,0x015b},
  {0x015c,0x015d},
  {0x015e,0x015f},
  {0x0160,0x0161},
  {0x0162,0x0163},
  {0x0164,0x0165},
  {0x0166,0x0167},
  {0x0168,0x0169},
  {0x016a,0x016b},
  {0x016c,0x016d},
  {0x016e,0x016f},
  {0x0170,0x0171},
  {0x0172,0x0173},
  {0x0174,0x0175},
  {0x0176,0x0177},
  {0x0179,0x017a},
  {0x017b,0x017c},
  {0x017d,0x017e},
  {0x0187,0x0188},
  {0x0191,0x0192},
  {0x0198,0x0199},
  {0x01a0,0x01a1},
  {0x01a2,0x01a3},
  {0x01af,0x01b0},
  {0x01b5,0x01b6},
  {0x01b7,0x0292},
  {0x01cd,0x01ce},
  {0x01cf,0x01d0},
  {0x01d1,0x01d2},
  {0x01d3,0x01d4},
  {0x01d5,0x01d6},
  {0x01d7,0x01d8},
  {0x01d9,0x01da},
  {0x01db,0x01dc},
  {0x01de,0x01df},
  {0x01e0,0x01e1},
  {0x01e2,0x01e3},
  {0x01e4,0x01e5},
  {0x01e6,0x01e7},
  {0x01e8,0x01e9},
  {0x01ea,0x01eb},
  {0x01ec,0x01ed},
  {0x01ee,0x01ef},
  {0x01f8,0x01f9},
  {0x01fa,0x01fb},
  {0x01fc,0x01fd},
  {0x0200,0x0201},
  {0x0202,0x0203},
  {0x0204,0x0205},
  {0x0206,0x0207},
  {0x0208,0x0209},
  {0x020a,0x020b},
  {0x020c,0x020d},
  {0x020e,0x020f},
  {0x0210,0x0211},
  {0x0212,0x0213},
  {0x0214,0x0215},
  {0x0216,0x0217},
  {0x0386,0x03ac},
  {0x0388,0x03ad},
  {0x0389,0x03ae},
  {0x038a,0x03af},
  {0x038c,0x03cc},
  {0x038e,0x03cd},
  {0x038f,0x03ce},
  {0x0391,0x03b1},
  {0x0392,0x03b2},
  {0x0393,0x03b3},
  {0x0394,0x03b4},
  {0x0395,0x03b5},
  {0x0396,0x03b6},
  {0x0397,0x03b7},
  {0x0398,0x03b8},
  {0x0399,0x03b9},
  {0x039a,0x03ba},
  {0x039b,0x03bb},
  {0x039c,0x03bc},
  {0x039d,0x03bd},
  {0x039e,0x03be},
  {0x039f,0x03bf},
  {0x03a0,0x03c0},
  {0x03a1,0x03c1},
  {0x03a3,0x03c3},
  {0x03a4,0x03c4},
  {0x03a5,0x03c5},
  {0x03a6,0x03c6},
  {0x03a7,0x03c7},
  {0x03a8,0x03c8},
  {0x03a9,0x03c9},
  {0x03aa,0x03ca},
  {0x03ab,0x03cb},
  {0x0401,0x0451},
  {0x0402,0x0452},
  {0x0403,0x0453},
  {0x0404,0x0454},
  {0x0405,0x0455},
  {0x0406,0x0456},
  {0x0407,0x0457},
  {0x0408,0x0458},
  {0x0409,0x0459},
  {0x040a,0x045a},
  {0x040b,0x045b},
  {0x040c,0x045c},
  {0x040f,0x045f},
  {0x0410,0x0430},
  {0x0411,0x0431},
  {0x0412,0x0432},
  {0x0413,0x0433},
  {0x0414,0x0434},
  {0x0415,0x0435},
  {0x0416,0x0436},
  {0x0417,0x0437},
  {0x0418,0x0438},
  {0x0419,0x0439},
  {0x041a,0x043a},
  {0x041b,0x043b},
  {0x041c,0x043c},
  {0x041d,0x043d},
  {0x041e,0x043e},
  {0x041f,0x043f},
  {0x0420,0x0440},
  {0x0421,0x0441},
  {0x0422,0x0442},
  {0x0423,0x0443},
  {0x0424,0x0444},
  {0x0425,0x0445},
  {0x0426,0x0446},
  {0x0427,0x0447},
  {0x0428,0x0448},
  {0x0429,0x0449},
  {0x042a,0x044a},
  {0x042b,0x044b},
  {0x042c,0x044c},
  {0x042d,0x044d},
  {0x042e,0x044e},
  {0x042f,0x044f},
  {0x0462,0x0463},
  {0x046a,0x046b},
  {0x0472,0x0473},
  {0x0474,0x0475},
  {0x0480,0x0481},
  {0x0490,0x0491},
  {0x1e00,0x1e01},
  {0x1e02,0x1e03},
  {0x1e04,0x1e05},
  {0x1e06,0x1e07},
  {0x1e08,0x1e09},
  {0x1e0a,0x1e0b},
  {0x1e0c,0x1e0d},
  {0x1e0e,0x1e0f},
  {0x1e10,0x1e11},
  {0x1e12,0x1e13},
  {0x1e14,0x1e15},
  {0x1e16,0x1e17},
  {0x1e18,0x1e19},
  {0x1e1a,0x1e1b},
  {0x1e1c,0x1e1d},
  {0x1e1e,0x1e1f},
  {0x1e20,0x1e21},
  {0x1e22,0x1e23},
  {0x1e24,0x1e25},
  {0x1e26,0x1e27},
  {0x1e28,0x1e29},
  {0x1e2a,0x1e2b},
  {0x1e2c,0x1e2d},
  {0x1e2e,0x1e2f},
  {0x1e30,0x1e31},
  {0x1e32,0x1e33},
  {0x1e34,0x1e35},
  {0x1e36,0x1e37},
  {0x1e38,0x1e39},
  {0x1e3a,0x1e3b},
  {0x1e3c,0x1e3d},
  {0x1e3e,0x1e3f},
  {0x1e40,0x1e41},
  {0x1e42,0x1e43},
  {0x1e44,0x1e45},
  {0x1e46,0x1e47},
  {0x1e48,0x1e49},
  {0x1e4a,0x1e4b},
  {0x1e4c,0x1e4d},
  {0x1e4e,0x1e4f},
  {0x1e50,0x1e51},
  {0x1e52,0x1e53},
  {0x1e54,0x1e55},
  {0x1e56,0x1e57},
  {0x1e58,0x1e59},
  {0x1e5a,0x1e5b},
  {0x1e5c,0x1e5d},
  {0x1e5e,0x1e5f},
  {0x1e60,0x1e61},
  {0x1e62,0x1e63},
  {0x1e64,0x1e65},
  {0x1e66,0x1e67},
  {0x1e68,0x1e69},
  {0x1e6a,0x1e6b},
  {0x1e6c,0x1e6d},
  {0x1e6e,0x1e6f},
  {0x1e70,0x1e71},
  {0x1e72,0x1e73},
  {0x1e74,0x1e75},
  {0x1e76,0x1e77},
  {0x1e78,0x1e79},
  {0x1e7a,0x1e7b},
  {0x1e7c,0x1e7d},
  {0x1e7e,0x1e7f},
  {0x1e80,0x1e81},
  {0x1e82,0x1e83},
  {0x1e84,0x1e85},
  {0x1e86,0x1e87},
  {0x1e88,0x1e89},
  {0x1e8a,0x1e8b},
  {0x1e8c,0x1e8d},
  {0x1e8e,0x1e8f},
  {0x1e90,0x1e91},
  {0x1e92,0x1e93},
  {0x1e94,0x1e95},
  {0x1ea0,0x1ea1},
  {0x1ea2,0x1ea3},
  {0x1ea4,0x1ea5},
  {0x1ea6,0x1ea7},
  {0x1ea8,0x1ea9},
  {0x1eaa,0x1eab},
  {0x1eac,0x1ead},
  {0x1eae,0x1eaf},
  {0x1eb0,0x1eb1},
  {0x1eb2,0x1eb3},
  {0x1eb4,0x1eb5},
  {0x1eb6,0x1eb7},
  {0x1eb8,0x1eb9},
  {0x1eba,0x1ebb},
  {0x1ebc,0x1ebd},
  {0x1ebe,0x1ebf},
  {0x1ec0,0x1ec1},
  {0x1ec2,0x1ec3},
  {0x1ec4,0x1ec5},
  {0x1ec6,0x1ec7},
  {0x1ec8,0x1ec9},
  {0x1eca,0x1ecb},
  {0x1ecc,0x1ecd},
  {0x1ece,0x1ecf},
  {0x1ed0,0x1ed1},
  {0x1ed2,0x1ed3},
  {0x1ed4,0x1ed5},
  {0x1ed6,0x1ed7},
  {0x1ed8,0x1ed9},
  {0x1eda,0x1edb},
  {0x1edc,0x1edd},
  {0x1ede,0x1edf},
  {0x1ee0,0x1ee1},
  {0x1ee2,0x1ee3},
  {0x1ee4,0x1ee5},
  {0x1ee6,0x1ee7},
  {0x1ee8,0x1ee9},
  {0x1eea,0x1eeb},
  {0x1eec,0x1eed},
  {0x1eee,0x1eef},
  {0x1ef0,0x1ef1},
  {0x1ef2,0x1ef3},
  {0x1ef4,0x1ef5},
  {0x1ef6,0x1ef7},
  {0x1ef8,0x1ef9},
  {0x24b6,0x24d0},
  {0x24b7,0x24d1},
  {0x24b8,0x24d2},
  {0x24b9,0x24d3},
  {0x24ba,0x24d4},
  {0x24bb,0x24d5},
  {0x24bc,0x24d6},
  {0x24bd,0x24d7},
  {0x24be,0x24d8},
  {0x24bf,0x24d9},
  {0x24c0,0x24da},
  {0x24c1,0x24db},
  {0x24c2,0x24dc},
  {0x24c3,0x24dd},
  {0x24c4,0x24de},
  {0x24c5,0x24df},
  {0x24c6,0x24e0},
  {0x24c7,0x24e1},
  {0x24c8,0x24e2},
  {0x24c9,0x24e3},
  {0x24ca,0x24e4},
  {0x24cb,0x24e5},
  {0x24cc,0x24e6},
  {0x24cd,0x24e7},
  {0x24ce,0x24e8},
  {0x24cf,0x24e9},
};

unichar t_toupper[][2]=
{
  {0x0061,0x0041},
  {0x0062,0x0042},
  {0x0063,0x0043},
  {0x0064,0x0044},
  {0x0065,0x0045},
  {0x0066,0x0046},
  {0x0067,0x0047},
  {0x0068,0x0048},
  {0x0069,0x0049},
  {0x006a,0x004a},
  {0x006b,0x004b},
  {0x006c,0x004c},
  {0x006d,0x004d},
  {0x006e,0x004e},
  {0x006f,0x004f},
  {0x0070,0x0050},
  {0x0071,0x0051},
  {0x0072,0x0052},
  {0x0073,0x0053},
  {0x0074,0x0054},
  {0x0075,0x0055},
  {0x0076,0x0056},
  {0x0077,0x0057},
  {0x0078,0x0058},
  {0x0079,0x0059},
  {0x007a,0x005a},
  {0x00e0,0x00c0},
  {0x00e1,0x00c1},
  {0x00e2,0x00c2},
  {0x00e3,0x00c3},
  {0x00e4,0x00c4},
  {0x00e5,0x00c5},
  {0x00e6,0x00c6},
  {0x00e7,0x00c7},
  {0x00e8,0x00c8},
  {0x00e9,0x00c9},
  {0x00ea,0x00ca},
  {0x00eb,0x00cb},
  {0x00ec,0x00cc},
  {0x00ed,0x00cd},
  {0x00ee,0x00ce},
  {0x00ef,0x00cf},
  {0x00f0,0x00d0},
  {0x00f1,0x00d1},
  {0x00f2,0x00d2},
  {0x00f3,0x00d3},
  {0x00f4,0x00d4},
  {0x00f5,0x00d5},
  {0x00f6,0x00d6},
  {0x00f8,0x00d8},
  {0x00f9,0x00d9},
  {0x00fa,0x00da},
  {0x00fb,0x00db},
  {0x00fc,0x00dc},
  {0x00fd,0x00dd},
  {0x00fe,0x00de},
  {0x0101,0x0100},
  {0x0103,0x0102},
  {0x0105,0x0104},
  {0x0107,0x0106},
  {0x0109,0x0108},
  {0x010b,0x010a},
  {0x010d,0x010c},
  {0x010f,0x010e},
  {0x0111,0x0110},
  {0x0113,0x0112},
  {0x0115,0x0114},
  {0x0117,0x0116},
  {0x0119,0x0118},
  {0x011b,0x011a},
  {0x011d,0x011c},
  {0x011f,0x011e},
  {0x0121,0x0120},
  {0x0123,0x0122},
  {0x0125,0x0124},
  {0x0127,0x0126},
  {0x0129,0x0128},
  {0x012b,0x012a},
  {0x012d,0x012c},
  {0x012f,0x012e},
  {0x0131,0x0130},
  {0x0133,0x0132},
  {0x0135,0x0134},
  {0x0137,0x0136},
  {0x013a,0x0139},
  {0x013c,0x013b},
  {0x013e,0x013d},
  {0x0140,0x013f},
  {0x0142,0x0141},
  {0x0144,0x0143},
  {0x0146,0x0145},
  {0x0148,0x0147},
  {0x014b,0x014a},
  {0x014d,0x014c},
  {0x014f,0x014e},
  {0x0151,0x0150},
  {0x0153,0x0152},
  {0x0155,0x0154},
  {0x0157,0x0156},
  {0x0159,0x0158},
  {0x015b,0x015a},
  {0x015d,0x015c},
  {0x015f,0x015e},
  {0x0161,0x0160},
  {0x0163,0x0162},
  {0x0165,0x0164},
  {0x0167,0x0166},
  {0x0169,0x0168},
  {0x016b,0x016a},
  {0x016d,0x016c},
  {0x016f,0x016e},
  {0x0171,0x0170},
  {0x0173,0x0172},
  {0x0175,0x0174},
  {0x0177,0x0176},
  {0x017a,0x0179},
  {0x017c,0x017b},
  {0x017e,0x017d},
  {0x0188,0x0187},
  {0x0192,0x0191},
  {0x0199,0x0198},
  {0x01a1,0x01a0},
  {0x01a3,0x01a2},
  {0x01b0,0x01af},
  {0x01b6,0x01b5},
  {0x01ce,0x01cd},
  {0x01d0,0x01cf},
  {0x01d2,0x01d1},
  {0x01d4,0x01d3},
  {0x01d6,0x01d5},
  {0x01d8,0x01d7},
  {0x01da,0x01d9},
  {0x01dc,0x01db},
  {0x01df,0x01de},
  {0x01e1,0x01e0},
  {0x01e3,0x01e2},
  {0x01e5,0x01e4},
  {0x01e7,0x01e6},
  {0x01e9,0x01e8},
  {0x01eb,0x01ea},
  {0x01ed,0x01ec},
  {0x01ef,0x01ee},
  {0x01f9,0x01f8},
  {0x01fb,0x01fa},
  {0x01fd,0x01fc},
  {0x0201,0x0200},
  {0x0203,0x0202},
  {0x0205,0x0204},
  {0x0207,0x0206},
  {0x0209,0x0208},
  {0x020b,0x020a},
  {0x020d,0x020c},
  {0x020f,0x020e},
  {0x0211,0x0210},
  {0x0213,0x0212},
  {0x0215,0x0214},
  {0x0217,0x0216},
  {0x0292,0x01b7},
  {0x03ac,0x0386},
  {0x03ad,0x0388},
  {0x03ae,0x0389},
  {0x03af,0x038a},
  {0x03b1,0x0391},
  {0x03b2,0x0392},
  {0x03b3,0x0393},
  {0x03b4,0x0394},
  {0x03b5,0x0395},
  {0x03b6,0x0396},
  {0x03b7,0x0397},
  {0x03b8,0x0398},
  {0x03b9,0x0399},
  {0x03ba,0x039a},
  {0x03bb,0x039b},
  {0x03bc,0x039c},
  {0x03bd,0x039d},
  {0x03be,0x039e},
  {0x03bf,0x039f},
  {0x03c0,0x03a0},
  {0x03c1,0x03a1},
  {0x03c2,0x03a3},
  {0x03c3,0x03a3},
  {0x03c4,0x03a4},
  {0x03c5,0x03a5},
  {0x03c6,0x03a6},
  {0x03c7,0x03a7},
  {0x03c8,0x03a8},
  {0x03c9,0x03a9},
  {0x03ca,0x03aa},
  {0x03cb,0x03ab},
  {0x03cc,0x038c},
  {0x03cd,0x038e},
  {0x03ce,0x038f},
  {0x0430,0x0410},
  {0x0431,0x0411},
  {0x0432,0x0412},
  {0x0433,0x0413},
  {0x0434,0x0414},
  {0x0435,0x0415},
  {0x0436,0x0416},
  {0x0437,0x0417},
  {0x0438,0x0418},
  {0x0439,0x0419},
  {0x043a,0x041a},
  {0x043b,0x041b},
  {0x043c,0x041c},
  {0x043d,0x041d},
  {0x043e,0x041e},
  {0x043f,0x041f},
  {0x0440,0x0420},
  {0x0441,0x0421},
  {0x0442,0x0422},
  {0x0443,0x0423},
  {0x0444,0x0424},
  {0x0445,0x0425},
  {0x0446,0x0426},
  {0x0447,0x0427},
  {0x0448,0x0428},
  {0x0449,0x0429},
  {0x044a,0x042a},
  {0x044b,0x042b},
  {0x044c,0x042c},
  {0x044d,0x042d},
  {0x044e,0x042e},
  {0x044f,0x042f},
  {0x0451,0x0401},
  {0x0452,0x0402},
  {0x0453,0x0403},
  {0x0454,0x0404},
  {0x0455,0x0405},
  {0x0456,0x0406},
  {0x0457,0x0407},
  {0x0458,0x0408},
  {0x0459,0x0409},
  {0x045a,0x040a},
  {0x045b,0x040b},
  {0x045c,0x040c},
  {0x045f,0x040f},
  {0x0463,0x0462},
  {0x046b,0x046a},
  {0x0473,0x0472},
  {0x0475,0x0474},
  {0x0481,0x0480},
  {0x0491,0x0490},
  {0x1e01,0x1e00},
  {0x1e03,0x1e02},
  {0x1e05,0x1e04},
  {0x1e07,0x1e06},
  {0x1e09,0x1e08},
  {0x1e0b,0x1e0a},
  {0x1e0d,0x1e0c},
  {0x1e0f,0x1e0e},
  {0x1e11,0x1e10},
  {0x1e13,0x1e12},
  {0x1e15,0x1e14},
  {0x1e17,0x1e16},
  {0x1e19,0x1e18},
  {0x1e1b,0x1e1a},
  {0x1e1d,0x1e1c},
  {0x1e1f,0x1e1e},
  {0x1e21,0x1e20},
  {0x1e23,0x1e22},
  {0x1e25,0x1e24},
  {0x1e27,0x1e26},
  {0x1e29,0x1e28},
  {0x1e2b,0x1e2a},
  {0x1e2d,0x1e2c},
  {0x1e2f,0x1e2e},
  {0x1e31,0x1e30},
  {0x1e33,0x1e32},
  {0x1e35,0x1e34},
  {0x1e37,0x1e36},
  {0x1e39,0x1e38},
  {0x1e3b,0x1e3a},
  {0x1e3d,0x1e3c},
  {0x1e3f,0x1e3e},
  {0x1e41,0x1e40},
  {0x1e43,0x1e42},
  {0x1e45,0x1e44},
  {0x1e47,0x1e46},
  {0x1e49,0x1e48},
  {0x1e4b,0x1e4a},
  {0x1e4d,0x1e4c},
  {0x1e4f,0x1e4e},
  {0x1e51,0x1e50},
  {0x1e53,0x1e52},
  {0x1e55,0x1e54},
  {0x1e57,0x1e56},
  {0x1e59,0x1e58},
  {0x1e5b,0x1e5a},
  {0x1e5d,0x1e5c},
  {0x1e5f,0x1e5e},
  {0x1e61,0x1e60},
  {0x1e63,0x1e62},
  {0x1e65,0x1e64},
  {0x1e67,0x1e66},
  {0x1e69,0x1e68},
  {0x1e6b,0x1e6a},
  {0x1e6d,0x1e6c},
  {0x1e6f,0x1e6e},
  {0x1e71,0x1e70},
  {0x1e73,0x1e72},
  {0x1e75,0x1e74},
  {0x1e77,0x1e76},
  {0x1e79,0x1e78},
  {0x1e7b,0x1e7a},
  {0x1e7d,0x1e7c},
  {0x1e7f,0x1e7e},
  {0x1e81,0x1e80},
  {0x1e83,0x1e82},
  {0x1e85,0x1e84},
  {0x1e87,0x1e86},
  {0x1e89,0x1e88},
  {0x1e8b,0x1e8a},
  {0x1e8d,0x1e8c},
  {0x1e8f,0x1e8e},
  {0x1e91,0x1e90},
  {0x1e93,0x1e92},
  {0x1e95,0x1e94},
  {0x1ea1,0x1ea0},
  {0x1ea3,0x1ea2},
  {0x1ea5,0x1ea4},
  {0x1ea7,0x1ea6},
  {0x1ea9,0x1ea8},
  {0x1eab,0x1eaa},
  {0x1ead,0x1eac},
  {0x1eaf,0x1eae},
  {0x1eb1,0x1eb0},
  {0x1eb3,0x1eb2},
  {0x1eb5,0x1eb4},
  {0x1eb7,0x1eb6},
  {0x1eb9,0x1eb8},
  {0x1ebb,0x1eba},
  {0x1ebd,0x1ebc},
  {0x1ebf,0x1ebe},
  {0x1ec1,0x1ec0},
  {0x1ec3,0x1ec2},
  {0x1ec5,0x1ec4},
  {0x1ec7,0x1ec6},
  {0x1ec9,0x1ec8},
  {0x1ecb,0x1eca},
  {0x1ecd,0x1ecc},
  {0x1ecf,0x1ece},
  {0x1ed1,0x1ed0},
  {0x1ed3,0x1ed2},
  {0x1ed5,0x1ed4},
  {0x1ed7,0x1ed6},
  {0x1ed9,0x1ed8},
  {0x1edb,0x1eda},
  {0x1edd,0x1edc},
  {0x1edf,0x1ede},
  {0x1ee1,0x1ee0},
  {0x1ee3,0x1ee2},
  {0x1ee5,0x1ee4},
  {0x1ee7,0x1ee6},
  {0x1ee9,0x1ee8},
  {0x1eeb,0x1eea},
  {0x1eed,0x1eec},
  {0x1eef,0x1eee},
  {0x1ef1,0x1ef0},
  {0x1ef3,0x1ef2},
  {0x1ef5,0x1ef4},
  {0x1ef7,0x1ef6},
  {0x1ef9,0x1ef8},
  {0x24d0,0x24b6},
  {0x24d1,0x24b7},
  {0x24d2,0x24b8},
  {0x24d3,0x24b9},
  {0x24d4,0x24ba},
  {0x24d5,0x24bb},
  {0x24d6,0x24bc},
  {0x24d7,0x24bd},
  {0x24d8,0x24be},
  {0x24d9,0x24bf},
  {0x24da,0x24c0},
  {0x24db,0x24c1},
  {0x24dc,0x24c2},
  {0x24dd,0x24c3},
  {0x24de,0x24c4},
  {0x24df,0x24c5},
  {0x24e0,0x24c6},
  {0x24e1,0x24c7},
  {0x24e2,0x24c8},
  {0x24e3,0x24c9},
  {0x24e4,0x24ca},
  {0x24e5,0x24cb},
  {0x24e6,0x24cc},
  {0x24e7,0x24cd},
  {0x24e8,0x24ce},
  {0x24e9,0x24cf},
};