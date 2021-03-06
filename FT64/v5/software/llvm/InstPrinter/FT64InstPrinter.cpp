//===-- FT64InstPrinter.cpp - Convert FT64 MCInst to asm syntax ---------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This class prints an FT64 MCInst to a .s file.
//
//===----------------------------------------------------------------------===//

#include "FT64InstPrinter.h"
#include "MCTargetDesc/FT64BaseInfo.h"
#include "MCTargetDesc/FT64MCExpr.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/FormattedStream.h"
using namespace llvm;

#define DEBUG_TYPE "asm-printer"

// Include the auto-generated portion of the assembly writer.
#define PRINT_ALIAS_INSTR
#include "FT64GenAsmWriter.inc"

// Include the auto-generated portion of the compress emitter.
#define GEN_UNCOMPRESS_INSTR
#include "FT64GenCompressInstEmitter.inc"

static cl::opt<bool>
NoAliases("FT64-no-aliases",
            cl::desc("Disable the emission of assembler pseudo instructions"),
            cl::init(false),
            cl::Hidden);

void FT64InstPrinter::printInst(const MCInst *MI, raw_ostream &O,
                                 StringRef Annot, const MCSubtargetInfo &STI) {
  bool Res = false;
  const MCInst *NewMI = MI;
  MCInst UncompressedMI;
  if (!NoAliases)
    Res = uncompressInst(UncompressedMI, *MI, MRI, STI);
  if (Res)
    NewMI = const_cast<MCInst*>(&UncompressedMI);
  if (NoAliases || !printAliasInstr(NewMI, STI, O))
    printInstruction(NewMI, STI, O);
  printAnnotation(O, Annot);
}

void FT64InstPrinter::printRegName(raw_ostream &O, unsigned RegNo) const {
  O << getRegisterName(RegNo);
}

void FT64InstPrinter::printOperand(const MCInst *MI, unsigned OpNo,
                                    const MCSubtargetInfo &STI,
                                    raw_ostream &O, const char *Modifier) {
  assert((Modifier == 0 || Modifier[0] == 0) && "No modifiers supported");
  const MCOperand &MO = MI->getOperand(OpNo);

  if (MO.isReg()) {
    printRegName(O, MO.getReg());
    return;
  }

  if (MO.isImm()) {
    O << MO.getImm();
    return;
  }

  assert(MO.isExpr() && "Unknown operand kind in printOperand");
  MO.getExpr()->print(O, &MAI);
}

void FT64InstPrinter::printFenceArg(const MCInst *MI, unsigned OpNo,
                                     const MCSubtargetInfo &STI,
                                     raw_ostream &O) {
  unsigned FenceArg = MI->getOperand(OpNo).getImm();
  if ((FenceArg & FT64FenceField::I) != 0)
    O << 'i';
  if ((FenceArg & FT64FenceField::O) != 0)
    O << 'o';
  if ((FenceArg & FT64FenceField::R) != 0)
    O << 'r';
  if ((FenceArg & FT64FenceField::W) != 0)
    O << 'w';
}

void FT64InstPrinter::printFRMArg(const MCInst *MI, unsigned OpNo,
                                   const MCSubtargetInfo &STI,
                                   raw_ostream &O) {
  auto FRMArg =
      static_cast<FT64FPRndMode::RoundingMode>(MI->getOperand(OpNo).getImm());
  O << FT64FPRndMode::roundingModeToString(FRMArg);
}
