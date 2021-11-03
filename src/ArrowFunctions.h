#ifdef __cplusplus
extern "C" {
#endif

  #define ARROWINT64 0
  #define ARROWINT32 1
  #define ARROWUNDEFINED -1
  
  int c_getNumRows(const char*);
  int cpp_getNumRows(const char*);

  void c_readColumnByName(const char* filename, void* chpl_arr,
                          const char* colname, int numElems);
  void cpp_readColumnByName(const char* filename, void* chpl_arr,
                            const char* colname, int numElems);

  int c_getType(const char* filename, const char* colname);
  int cpp_getType(const char* filename, const char* colname);

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
