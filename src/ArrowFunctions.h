#ifdef __cplusplus
extern "C" {
#endif

  int c_getNumRows(const char*);
  int cpp_getNumRows(const char*);

  int c_readColumnByName(const char* filename, void* chpl_arr,
                         const char* colname, int numElems);
  int cpp_readColumnByName(const char* filename, void* chpl_arr,
                           const char* colname, int numElems);

  int c_getType(const char* filename, const char* colname);
  int cpp_getType(const char* filename, const char* colname);

  int cpp_writeColumnToParquet(const char* filename, void* chpl_arr,
                               int colnum, const char* dsetname, int numelems,
                               int rowGroupSize);
  int c_writeColumnToParquet(const char* filename, void* chpl_arr,
                             int colnum, const char* dsetname, int numelems,
                             int rowGroupSize);;
    
  const char* c_getVersionInfo(void);
  const char* cpp_getVersionInfo(void);
  
#ifdef __cplusplus
}
#endif
