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

#include <isa.h>
#include <memory/vaddr.h>

/* We use the POSIX regex functions to process regular expressions.
 * Type 'man regex' for more information about POSIX regex functions.
 */
#include <regex.h>

enum {
  TK_NOTYPE = 256,
  TK_UMINUS, // unary -
  TK_DEREF,  // unary *
  TK_EQ,     // ==
  TK_NEQ,    // !=
  TK_AND,    // &&
  TK_DEC,    // decimal
  TK_HEX,    // hexadecimal
  TK_REG,    // register name
};

static struct rule {
  const char *regex;
  int token_type;
} rules[] = {
  {"$x[a-z0-9]+", TK_REG}, // register name
  {"0x[a-f0-9]+", TK_HEX}, // hexadecimal
  {"[0-9]+", TK_DEC},   // decimal
  {" +", TK_NOTYPE},    // spaces
  {"\n+", TK_NOTYPE},    // spaces
  {"&&", TK_AND},       // and
  {"==", TK_EQ},        // equal
  {"!=", TK_NEQ},       // not equal
  {"\\+", '+'},         // plus
  {"-", '-'},           // minus
  {"\\*", '*'},         // multiply
  {"/", '/'},           // divide
  {"\\(", '('},         // left parenthesis
  {")", ')'},           // right parenthesis
};

#define NR_REGEX ARRLEN(rules)

static regex_t re[NR_REGEX] = {};

/* Rules are used for many times.
 * Therefore we compile them only once before any usage.
 */
void init_regex() {
  int i;
  char error_msg[128];
  int ret;

  for (i = 0; i < NR_REGEX; i ++) {
    ret = regcomp(&re[i], rules[i].regex, REG_EXTENDED);
    if (ret != 0) {
      regerror(ret, &re[i], error_msg, 128);
      panic("regex compilation failed: %s\n%s", error_msg, rules[i].regex);
    }
  }
}

#define MAX_TOKEN_LEN 32

typedef struct token {
  int type;
  char str[MAX_TOKEN_LEN];
} Token;

#define MAX_NR_TOKENS 32

static Token tokens[MAX_NR_TOKENS] = {};
static int nr_token = 0;

static inline bool is_op(int tok_type) {
  return tok_type == '+'
      || tok_type == '-'
      || tok_type == '*'
      || tok_type == '/'
      || tok_type == TK_EQ
      || tok_type == TK_NEQ
      || tok_type == TK_AND
      || tok_type == TK_DEREF
      || tok_type == TK_UMINUS;
}

static bool make_token(char *e) {
  int position = 0;
  int i;
  regmatch_t pmatch;

  nr_token = 0;

  while (e[position] != '\0') {
    /* Try all rules one by one. */
    for (i = 0; i < NR_REGEX; i++) {
      if (regexec(&re[i], e + position, 1, &pmatch, 0) == 0 && pmatch.rm_so == 0) {
        char *substr_start = e + position;
        int substr_len = pmatch.rm_eo;

        Log("match rules[%d] = \"%s\" at position %d with len %d: %.*s",
            i, rules[i].regex, position, substr_len, substr_len, substr_start);

        position += substr_len;

        if (rules[i].token_type == TK_NOTYPE) {
          break;
        }

        tokens[nr_token].type = rules[i].token_type;
        if (rules[i].token_type == '*') {
          if (nr_token == 0 || is_op(tokens[nr_token - 1].type)
            || tokens[nr_token - 1].type == '(') {
            tokens[nr_token].type = TK_DEREF;
          }
        } else if (rules[i].token_type == '-') {
          if (nr_token == 0 || is_op(tokens[nr_token - 1].type)
            || tokens[nr_token - 1].type == '(') {
            tokens[nr_token].type = TK_UMINUS;
          }
        }

        Assert(nr_token < MAX_NR_TOKENS, "Currently, number of tokens should be less than 32");

        switch (rules[i].token_type) {
          case TK_HEX:
          case TK_DEC: {
            Assert(substr_len < MAX_TOKEN_LEN, "length of decimal should be less than 32");
            strncpy(tokens[nr_token].str, substr_start, substr_len);
            tokens[nr_token].str[substr_len] = '\0';
          } break;
          default: break;
        }
        ++nr_token;
        break;
      }
    }

    if (i == NR_REGEX) {
      printf("no match at position %d\n%s\n%*.s^\n", position, e, position, "");
      return false;
    }
  }

  return true;
}

static bool check_parentheses(int p, int q) {
  if (tokens[p].type != '(' || tokens[q].type != ')') {
    return false;
  }

  int cnt = 0;
  for (int i = p; i <= q; ++i) {
    if (tokens[i].type == '(') {
      ++cnt;
    } else if (tokens[i].type == ')') {
      --cnt;
    }
    if (cnt < 0) {
      return false;
    }
  }

  Assert(cnt == 0, "Guess the cnt should be 0");

  return true;
}

static int dominant_operator(int p, int q) {
  int cnt = 0;
  int op = -1;
  int priority = -1;
  for (int i = p; i <= q; ++i) {
    if (tokens[i].type == '(') {
      ++cnt;
    } else if (tokens[i].type == ')') {
      --cnt;
    } else if (cnt == 0) {
      if (tokens[i].type == TK_DEREF || tokens[i].type == TK_UMINUS) {
        if (priority < 0) { // right associative
          priority = 0;
          op = i;
        }
      } else if (tokens[i].type == '*' || tokens[i].type == '/') {
        if (priority <= 1) { // left associative
          priority = 1;
          op = i;
        }
      } else if (tokens[i].type == '+' || tokens[i].type == '-') {
        if (priority <= 2) { // left associative
          priority = 2;
          op = i;
        }
      } else if (tokens[i].type == TK_EQ || tokens[i].type == TK_NEQ) {
        if (priority <= 3) { // left associative
          priority = 3;
          op = i;
        }
      } else if (tokens[i].type == TK_AND) {
        if (priority <= 4) { // left associative
          priority = 4;
          op = i;
        }
      }
    }
  }
  return op;
}

static sword_t eval(int p, int q) {
  bool success;
  sword_t result;

  if (p > q) {
    /* Bad expression */
    return -1;
  } else if (p == q) {
    if (tokens[p].type == TK_DEC) return strtol(tokens[p].str, NULL, 10);
    if (tokens[p].type == TK_HEX) return strtol(tokens[p].str, NULL, 16);

    // it must be a register
    result = isa_reg_str2val(tokens[p].str, &success);

    if (success) return result;

    panic("Not a valid terminal");
    return -1;
  } else if (check_parentheses(p, q) == true) {
    /* The expression is surrounded by a matched pair of parentheses.
     * If that is the case, just throw away the parentheses.
     */
    return eval(p + 1, q - 1);
  } else {
    int op = dominant_operator(p, q);
    Assert(op != -1, "No dominant operator");

    if (tokens[op].type == TK_DEREF) {
      Assert(op == p, "Dereference should be at the beginning of the expression");
      return vaddr_read(eval(op + 1, q), 4);
    } else if (tokens[op].type == TK_UMINUS) {
      Assert(op == p, "Unary minus should be at the beginning of the expression");
      return -eval(op + 1, q);
    }

    sword_t val1 = eval(p, op - 1);
    sword_t val2 = eval(op + 1, q);
    switch (tokens[op].type) {
      case '+':    return val1 + val2;
      case '-':    return val1 - val2;
      case '*':    return val1 * val2;
      case '/':    return val1 / val2;
      case TK_EQ:  return val1 == val2;
      case TK_NEQ: return val1 != val2;
      case TK_AND: return val1 && val2;
      default: Assert(0, "Invalid operator");
    }
  }
}

word_t expr(char *e, bool *success) {
  if (!make_token(e)) {
    *success = false;
    return 0;
  }

  int cnt = 0;
  for (int i = 0; i < nr_token; ++i) {
    if (tokens[i].type == '(') {
      ++cnt;
    } else if (tokens[i].type == ')') {
      --cnt;
    }
    if (cnt < 0) {
      *success = false;
      return 0;
    }
  }
  if (cnt != 0) {
    *success = false;
    return 0;
  }

  word_t ret = eval(0, nr_token - 1);
  *success = true;

  return ret;
}


