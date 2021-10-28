#include "ArrowFunctions.h"

#include <iostream>
#include <arrow/api.h>
#include <arrow/io/api.h>
#include <parquet/arrow/reader.h>
#include <parquet/arrow/writer.h>
#include <parquet/exception.h>
#include <parquet/api/reader.h>

using namespace std;

int cpp_getSize(const char* filename) {
  std::shared_ptr<arrow::io::ReadableFile> infile;
  PARQUET_ASSIGN_OR_THROW(
      infile,
      arrow::io::ReadableFile::Open(filename,
                                    arrow::default_memory_pool()));

  std::unique_ptr<parquet::arrow::FileReader> reader;
  PARQUET_THROW_NOT_OK(
      parquet::arrow::OpenFile(infile, arrow::default_memory_pool(), &reader));
  
  return reader -> parquet_reader() -> metadata() -> num_rows();
}

const char* cpp_getType(const char* filename, const char* colname) {
  std::shared_ptr<arrow::io::ReadableFile> infile;
  PARQUET_ASSIGN_OR_THROW(
      infile,
      arrow::io::ReadableFile::Open(filename,
                                    arrow::default_memory_pool()));

  std::unique_ptr<parquet::arrow::FileReader> reader;
  PARQUET_THROW_NOT_OK(
      parquet::arrow::OpenFile(infile, arrow::default_memory_pool(), &reader));
  
  std::shared_ptr<arrow::Schema> sc;
  std::shared_ptr<arrow::Schema>* out = &sc;
  PARQUET_THROW_NOT_OK(reader->GetSchema(out));

  auto ty = sc -> GetFieldByName(colname) -> type() -> name();
  const char* ret = ty.c_str();
  return ret;
}

void cpp_readColumnByName(const char* filename, void* chpl_arr, const char* colname, int numElems) {
  auto chpl_ptr = (int64_t*)chpl_arr;
  
  std::shared_ptr<arrow::io::ReadableFile> infile;
  PARQUET_ASSIGN_OR_THROW(
      infile,
      arrow::io::ReadableFile::Open(filename,
                                    arrow::default_memory_pool()));

  std::unique_ptr<parquet::arrow::FileReader> reader;
  PARQUET_THROW_NOT_OK(
      parquet::arrow::OpenFile(infile, arrow::default_memory_pool(), &reader));
  std::shared_ptr<arrow::ChunkedArray> array;

  std::shared_ptr<arrow::Schema> sc;
  std::shared_ptr<arrow::Schema>* out = &sc;
  PARQUET_THROW_NOT_OK(reader->GetSchema(out));

  auto idx = sc -> GetFieldIndex(colname);

  // TODO: give some kind of indication that it wasn't found
  if(idx == -1)
    idx = 0;
  
  PARQUET_THROW_NOT_OK(reader->ReadColumn(idx, &array));

  std::shared_ptr<arrow::Array> regular = array->chunk(0);
  auto int_arr = std::static_pointer_cast<arrow::Int64Array>(regular);

  for(int i = 0; i < numElems; i++) {
    chpl_ptr[i] = int_arr->Value(i);
  }
}

void cpp_writeColumnToParquet(const char* filename, void* chpl_arr,
                              int colnum, const char* dsetname, int numelems,
                              int rowGroupSize) {
  auto chpl_ptr = (int64_t*)chpl_arr;
  arrow::Int64Builder i64builder;
  for(int i = 0; i < numelems; i++)
    PARQUET_THROW_NOT_OK(i64builder.AppendValues({chpl_ptr[i]}));
  std::shared_ptr<arrow::Array> i64array;
  PARQUET_THROW_NOT_OK(i64builder.Finish(&i64array));

  std::shared_ptr<arrow::Schema> schema = arrow::schema(
                 {arrow::field(dsetname, arrow::int64())});

  auto table = arrow::Table::Make(schema, {i64array});

  std::shared_ptr<arrow::io::FileOutputStream> outfile;
  PARQUET_ASSIGN_OR_THROW(
      outfile,
      arrow::io::FileOutputStream::Open(filename));

  PARQUET_THROW_NOT_OK(
  parquet::arrow::WriteTable(*table, arrow::default_memory_pool(), outfile, rowGroupSize));
}

const char* cpp_getVersionInfo(void) {
  return arrow::GetBuildInfo().version_string.c_str();
}

extern "C" {
  int c_getSize(const char* chpl_str) {
    return cpp_getSize(chpl_str);
  }

  void c_readColumnByName(const char* filename, void* chpl_arr, const char* colname, int numElems) {
    cpp_readColumnByName(filename, chpl_arr, colname, numElems);
  }

  const char* c_getType(const char* filename, const char* colname) {
    return cpp_getType(filename, colname);   
  }

  void c_writeColumnToParquet(const char* filename, void* chpl_arr,
                              int colnum, const char* dsetname, int numelems,
                              int rowGroupSize) {
    cpp_writeColumnToParquet(filename, chpl_arr, colnum, dsetname,
                             numelems, rowGroupSize);
  }

  const char* c_getVersionInfo(void) {
    return cpp_getVersionInfo();
  }
}
