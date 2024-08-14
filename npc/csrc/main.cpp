#include <Vtop.h>
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <verilated.h>
#include <verilated_vcd_c.h>

int main(int argc, char *argv[]) {
  const std::unique_ptr<VerilatedContext> contextp = std::make_unique<VerilatedContext>();
  contextp->commandArgs(argc, argv);
  const std::unique_ptr<Vtop> top = std::make_unique<Vtop>(contextp.get(), "TOP");
  VerilatedVcdC* tfp = new VerilatedVcdC;
  top->trace(tfp, 99); // Trace 99 levels of hierarchy
  tfp->open("build/dump.vcd");

  const int sim_time = 10;
  while (contextp->time() < sim_time && !contextp->gotFinish()) {
    int a = rand() & 1;
    int b = rand() & 1;
    top->a = a;
    top->b = b;
    top->eval();
    printf("a = %d, b = %d, f = %d\n", a, b, top->f);
    assert(top->f == (a ^ b));
    tfp->dump(contextp->time());
    contextp->timeInc(1);

  }
  tfp->close();
  delete tfp;

  // Final model cleanup
  top->final();

  // Final simulation summary
  contextp->statsPrintSummary();

  // Return good completion status
  // Don't use exit() or destructor's may hang
  return 0;
}
