#ifdef __cplusplus
extern "C" {
#endif

  int c_getNumRows(const char*);
  int cpp_getNumRows(const char*);

  void c_readColumnByName(const char* filename, void* chpl_arr, const char* colname, int numElems);
  void cpp_readColumnByName(const char* filename, void* chpl_arr, const char* colname, int numElems);

  void c_getType(const char* filename, const char* colname, void* chpl_int);
  void cpp_getType(const char* filename, const char* colname, void* chpl_int);

  void cpp_writeColumnToParquet(const char* filename, void* chpl_arr,
                                int colnum, const char* dsetname, int numelems,
                                int rowGroupSize);
  void c_writeColumnToParquet(const char* filename, void* chpl_arr,
                              int colnum, const char* dsetname, int numelems,
                              int rowGroupSize);;
    
  const char* c_getVersionInfo(void);
  const char* cpp_getVersionInfo(void);
  
#ifdef __cplusplus
}
#endif
