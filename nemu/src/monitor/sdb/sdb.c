/***************************************************************************************
 * Copyright (c) 2014-2022 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan
 *PSL v2. You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
 *KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
 *NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#include "sdb.h"
#include <cpu/cpu.h>
#include <isa.h>
#include <readline/history.h>
#include <readline/readline.h>

static int is_batch_mode = false;

void init_regex();
void init_wp_pool();
void isa_reg_display();
word_t paddr_read(paddr_t addr, int len);

/* We use the `readline' library to provide more flexibility to read from stdin.
 */
static char *rl_gets() {
  static char *line_read = NULL;

  if (line_read) {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(nemu) ");

  if (line_read && *line_read) {
    add_history(line_read);
  }

  return line_read;
}

static int cmd_c(char *args) {
  cpu_exec(-1);
  return 0;
}

static int cmd_q(char *args) {
  nemu_state.state = NEMU_QUIT;
  return -1;
}

static int cmd_si(char *args) {
  int count = 1; // default: 1
  if (args) {
    sscanf(args, "%d", &count);
  }
  cpu_exec(count);
  return 0;
}

static int cmd_info(char *args) {
  if (!args) {
    printf("info r -- List of integer registers and their contents\n");
    printf("info w -- Status of all watchpoints\n");
    return 0;
  }

  if (!strcmp(args, "r")) {
    isa_reg_display();
    return 0;
  }

  if (!strcmp(args, "w")) {
    Assert(0, "Not implemented");
    return 0;
  }

  return 0;
}

static int cmd_x(char *args) {
  char *count_str = strtok(args, " "); // first token is count
  char *addr_str = strtok(NULL, ""); // remaining string is address expression
  int count, addr;
  bool success = true;
  sscanf(count_str, "%d", &count);
  addr = expr(addr_str, &success);
  if (!success) {
    printf("Invalid expression\n");
    return 0;
  }
  for (int i = 0; i < count; ++i) {
    printf("%02x ", paddr_read(addr + i, 1));
    if ((i + 1) % 16 == 0) {
      printf("\n");
    }
  }
  if (count % 16) {
    printf("\n");
  }
  return 0;
}

static int cmd_p(char *args) {
  bool success = true;
  word_t result = expr(args, &success);
  if (success) {
    // printf("0x%x\n", result);
    printf("%u\n", result);
  } else {
    printf("Invalid expression\n");
  }
  return 0;
}

static int cmd_test(char *args) {
  char filename[] = "/tmp/rand-input.txt";
  char buf[1024];
  char *ptr;
  word_t expected;
  FILE *fp = fopen(filename, "r");

  printf("Test expression evaluate\n");

  if (fp == NULL) {
    printf(ANSI_FMT("Error: cannot open file %s\n", ANSI_FG_YELLOW), filename);
    return 0;
  }
  while (fgets(buf, sizeof(buf), fp) != NULL) {
    bool success = true;
    ptr = strtok(buf, " ");
    expected = strtol(ptr, NULL, 10);
    ptr = strtok(NULL, "");

    word_t result = expr(ptr, &success);

    Assert(success, "Invalid expression: %s", buf);
    if (result == expected) {
      printf(ANSI_FMT("Pass\n", ANSI_FG_GREEN));
    } else {
      printf(ANSI_FMT("Fail: expected %u, got %u\n", ANSI_FG_RED),
        expected, result);
    }
  }
  return 0;
}

// static int cmd_w(char *args);

// static int cmd_d(char *args);

static int cmd_help(char *args);

static struct {
  const char *name;
  const char *description;
  int (*handler)(char *);
} cmd_table[] = {
    {"help", "Display information about all supported commands", cmd_help},
    {"c", "Continue the execution of the program", cmd_c},
    {"q", "Exit NEMU", cmd_q},
    {"si", "Execute one machine instruction and do count times", cmd_si},
    {"info", "Display pragram status", cmd_info},
    {"x", "Examine memory", cmd_x},
    {"p", "Evaluate expression", cmd_p},

    {"test", "Test certain functionality", cmd_test},

    // TODO: Add more commands

};

#define NR_CMD ARRLEN(cmd_table)

static int cmd_help(char *args) {
  /* extract the first argument */
  char *arg = strtok(NULL, " ");
  int i;

  if (arg == NULL) {
    /* no argument given */
    for (i = 0; i < NR_CMD; i++) {
      printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
    }
  } else {
    for (i = 0; i < NR_CMD; i++) {
      if (strcmp(arg, cmd_table[i].name) == 0) {
        printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
        return 0;
      }
    }
    printf("Unknown command '%s'\n", arg);
  }
  return 0;
}

void sdb_set_batch_mode() { is_batch_mode = true; }

void sdb_mainloop() {
  if (is_batch_mode) {
    cmd_c(NULL);
    return;
  }

  for (char *str; (str = rl_gets()) != NULL;) {
    char *str_end = str + strlen(str);

    /* extract the first token as the command */
    char *cmd = strtok(str, " ");
    if (cmd == NULL) {
      continue;
    }

    /* treat the remaining string as the arguments,
     * which may need further parsing
     */
    char *args = cmd + strlen(cmd) + 1;
    if (args >= str_end) {
      args = NULL;
    }

#ifdef CONFIG_DEVICE
    extern void sdl_clear_event_queue();
    sdl_clear_event_queue();
#endif

    int i;
    for (i = 0; i < NR_CMD; i++) {
      if (strcmp(cmd, cmd_table[i].name) == 0) {
        if (cmd_table[i].handler(args) < 0) {
          return;
        }
        break;
      }
    }

    if (i == NR_CMD) {
      printf("Unknown command '%s'\n", cmd);
    }
  }
}

void init_sdb() {
  /* Compile the regular expressions. */
  init_regex();

  /* Initialize the watchpoint pool. */
  init_wp_pool();
}
