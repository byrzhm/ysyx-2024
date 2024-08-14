#include <Vtop.h>
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <verilated.h>
#include <verilated_vcd_c.h>

int main(int argc, char *argv[]) {
  const std::unique_ptr<VerilatedContext> ctxp = std::make_unique<VerilatedContext>();
  ctxp->commandArgs(argc, argv);
  const std::unique_ptr<Vtop> top = std::make_unique<Vtop>(ctxp.get(), "TOP");
  Verilated::traceEverOn(true);
  VerilatedVcdC* tfp = new VerilatedVcdC;
  top->trace(tfp, 99); // Trace 99 levels of hierarchy
  tfp->open("build/dump.vcd");

  int count = 10;
  while (count--) {
    ctxp->timeInc(1);

    int a = rand() & 1;
    int b = rand() & 1;
    top->a = a;
    top->b = b;
    top->eval();
    printf("a = %d, b = %d, f = %d\n", a, b, top->f);
    assert(top->f == (a ^ b));
    tfp->dump(ctxp->time());
  }
  tfp->close();
  delete tfp;

  // Final model cleanup
  top->final();

  // Final simulation summary
  ctxp->statsPrintSummary();

  // Return good completion status
  // Don't use exit() or destructor's may hang
  return 0;
}
