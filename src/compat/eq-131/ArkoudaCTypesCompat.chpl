module ArkoudaCTypesCompat {
  public use CTypes;
  type c_string_ptr = c_ptrConst(c_char);
}
