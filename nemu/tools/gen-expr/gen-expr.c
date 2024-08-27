/***************************************************************************************
* Copyright (c) 2014-2022 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <string.h>

// this should be enough
static char buf[65536] = {};
static char code_buf[65536 + 128] = {}; // a little larger than `buf`
static char *code_format =
"#include <stdio.h>\n"
"int main() { "
"  unsigned result = %s; "
"  printf(\"%%u\", result); "
"  return 0; "
"}";

static int pos = 0;
static int tok_nr = 0;

static int choose(int n) {
  return rand() % n;
}

static void clear() {
  pos = 0;
  tok_nr = 0;
  memset(buf, 0, sizeof(buf));
}

static void gen(char c) {
  buf[pos++] = c;
}

static void gen_lparen() {
  tok_nr++;
  gen('(');
}

static void gen_rparen() {
  tok_nr++;
  gen(')');
}

static void gen_num() {
  tok_nr++;
  gen(choose(9) + '1');
  for (int i = 0; i < choose(8); i++) {
    gen(choose(10) + '0');
  }
}

static void gen_rand_op() {
  tok_nr++;
  switch (choose(4)) {
    case 0: gen('+'); break;
    case 1: gen('-'); break;
    case 2: gen('*'); break;
    case 3:
    default: gen('/'); break;
  }
}

static void gen_rand_expr() {
  if (tok_nr > 15) {
    gen_num();
    return;
  }

  switch (choose(3)) {
    case 0: gen_num(); break;
    case 1: gen_lparen(); gen_rand_expr(); gen_rparen(); break;
    case 2:
    default: gen_rand_expr(); gen_rand_op(); gen_rand_expr(); break;
  }
}

int main(int argc, char *argv[]) {
  int seed = time(0);
  srand(seed);
  int loop = 1;
  if (argc > 1) {
    sscanf(argv[1], "%d", &loop);
  }
  int i;
  for (i = 0; i < loop; i ++) {
    do {
      clear();
      gen_rand_expr();
    } while (tok_nr < 3 || tok_nr > 31);

    sprintf(code_buf, code_format, buf);

    FILE *fp = fopen("/tmp/.code.c", "w");
    assert(fp != NULL);
    fputs(code_buf, fp);
    fclose(fp);

    int ret = system("gcc /tmp/.code.c -o /tmp/.expr");
    if (ret != 0) continue;

    fp = popen("/tmp/.expr", "r");
    assert(fp != NULL);

    int result;
    ret = fscanf(fp, "%d", &result);
    pclose(fp);

    printf("%u %s\n", result, buf);
  }
  return 0;
}
