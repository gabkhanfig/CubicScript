#pragma once
#define ROUND_SIZE_TO_MULTIPLE_OF_8(sizeOfType) (sizeOfType % 8 == 0 ? sizeOfType : sizeOfType + (8 - (sizeOfType % 8)))