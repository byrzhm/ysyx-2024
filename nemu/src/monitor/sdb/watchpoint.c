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

#include "sdb.h"

#define NR_WP 32

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;
  char *expr;
  word_t prev_val;
} WP;

static WP wp_pool[NR_WP] = {};
static WP *head = NULL, *free_ = NULL;

void init_wp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
  }

  head = NULL;
  free_ = wp_pool;
}

void new_wp(char *expr, word_t val) {
  WP *wp = NULL;

  if (free_ == NULL) {
    printf("No enough watchpoints.\n");
    assert(0);
  }

  wp = free_;
  free_ = free_->next;
  wp->next = head;
  head = wp;

  wp->expr = malloc(strlen(expr) + 1);
  strcpy(wp->expr, expr);
  wp->prev_val = val;
}

void free_wp(int no) {
  WP *wp = &wp_pool[no];
  if (wp->expr != NULL) {
    free(wp->expr);
    wp->expr = NULL;
  }

  WP *p = head;
  if (p == wp) {
    head = head->next;
    wp->next = free_;
    free_ = wp;
    return;
  }
  while (p->next != NULL) {
    if (p->next == wp) {
      p->next = wp->next;
      wp->next = free_;
      free_ = wp;
      return;
    }
    p = p->next;
  }
  Assert(0, "Watchpoint not found.");
}

bool polling_wp() {
  WP *wp = head;
  bool changed = false;

  while (wp != NULL) {
    bool success;
    word_t val = expr(wp->expr, &success);
    Assert(success, "Invalid expression: %s", wp->expr);

    if (val != wp->prev_val) {
      changed = true;
      printf("Watchpoint %d: %s\n", wp->NO, wp->expr);
      printf("\tOld value = %u\n", wp->prev_val);
      printf("\tNew value = %u\n", val);
      wp->prev_val = val;
    }
  }
  return changed;
}