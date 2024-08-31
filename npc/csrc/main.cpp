#include <Vtop.h>
#include <nvboard.h>
#include <svdpi.h>
#include <Vtop__Dpi.h>
#include <verilated.h>

static TOP_NAME dut;

void nvboard_bind_all_pins(TOP_NAME *top);

static bool running = true;

void halt() {
  running = false;
}

#define RESET_PC 0x80000000
#define CONFIG_MBASE 0x80000000
#define CONFIG_MSIZE 0x8000000
static uint8_t pmem[CONFIG_MSIZE] __attribute((aligned(4096))) = {};

uint8_t* guest_to_host(uint32_t paddr) { return pmem + paddr - CONFIG_MBASE; }
uint32_t host_to_guest(uint8_t *haddr) { return haddr - pmem + CONFIG_MBASE; }

static inline uint32_t host_read(void *addr) {
  return *(uint32_t *)addr;
}

static uint32_t pmem_read(uint32_t addr) {
  uint32_t ret = host_read(guest_to_host(addr));
  return ret;
}

static const uint32_t img [] = {
  0x06400293, // t0 <- 100
  0x0C800313, // t1 <- 200
  0x006283B3, // t2 <- t0 + t1
  0x00100073, // ebreak
};

static void init_mem() {
  memcpy(guest_to_host(RESET_PC), img, sizeof(img));
}


static void single_cycle() {
  dut.clk = 0; dut.eval();
  dut.clk = 1; dut.inst = pmem_read(dut.pc); dut.eval();
}

static void reset(int n) {
  dut.rst = 1;
  while (n-- > 0) single_cycle();
  dut.rst = 0;
}

int main(int argc, char *argv[]) {
  nvboard_bind_all_pins(&dut);
  nvboard_init();
  init_mem();
  reset(10);

  while (running) {
    nvboard_update();
    single_cycle();
  }
}
