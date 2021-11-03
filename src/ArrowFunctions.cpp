#include "ArrowFunctions.h"

#include <iostream>
#include <arrow/api.h>
#include <arrow/io/api.h>
#include <parquet/arrow/reader.h>
#include <parquet/arrow/writer.h>

int cpp_getNumRows(const char* filename) {
  try {
    std::shared_ptr<arrow::io::ReadableFile> infile;
    PARQUET_ASSIGN_OR_THROW(
        infile,
        arrow::io::ReadableFile::Open(filename,
                                      arrow::default_memory_pool()));

    std::unique_ptr<parquet::arrow::FileReader> reader;
    PARQUET_THROW_NOT_OK(
      parquet::arrow::OpenFile(infile, arrow::default_memory_pool(), &reader));
    return reader -> parquet_reader() -> metadata() -> num_rows();
  } catch (const ::parquet::ParquetStatusException& e) {
    // -2 corresponds to error opening file: file with filename not found
    return -2;
  }
}

int cpp_getType(const char* filename, const char* colname) {
  try {
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

    auto myType = sc -> GetFieldByName(colname) -> type();

    if(myType == NULL)
      // -3 corresponds to error with dsetname: schema does not contain dsetname
      return -3; 
    else if(myType == arrow::int64())
      return 0;
    else if(myType == arrow::int32())
      return 1;
    else // type not supported
      return -1;
  } catch(const ::parquet::ParquetStatusException& e) {
    // -2 corresponds to error opening file: file with filename not found
    return -2;
  }
}

int cpp_readColumnByName(const char* filename, void* chpl_arr, const char* colname, int numElems) {
  try {
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

    // -3 corresponds to error with dsetname: schema does not contain dsetname
    if(idx == -1)
      return -3;

    PARQUET_THROW_NOT_OK(reader->ReadColumn(idx, &array));

    int ty = cpp_getType(filename, colname);
    if(ty == -2) ty = 0;
    std::shared_ptr<arrow::Array> regular = array->chunk(0);
    // 0 is int64, 1 is int32
    if(ty == 0) {
      auto int_arr = std::static_pointer_cast<arrow::Int64Array>(regular);

      for(int i = 0; i < numElems; i++)
        chpl_ptr[i] = int_arr->Value(i);
    } else if(ty == 1) {
        auto int_arr = std::static_pointer_cast<arrow::Int32Array>(regular);

        for(int i = 0; i < numElems; i++)
          chpl_ptr[i] = int_arr->Value(i);
    }
    return 0;
  } catch(const ::parquet::ParquetStatusException& e) {
    // -2 corresponds to error opening file: file with filename not found
    return -2;
  }
}

int cpp_writeColumnToParquet(const char* filename, void* chpl_arr,
                              int colnum, const char* dsetname, int numelems,
                              int rowGroupSize) {
  try {
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
    return 0;
  } catch(const ::parquet::ParquetStatusException& e) {
    // -4 corresponds to error writing file: don't have permission to write filename
    return -4;
  }
}

const char* cpp_getVersionInfo(void) {
  return arrow::GetBuildInfo().version_string.c_str();
}

extern "C" {
  int c_getNumRows(const char* chpl_str) {
    return cpp_getNumRows(chpl_str);
  }

  int c_readColumnByName(const char* filename, void* chpl_arr, const char* colname, int numElems) {
    return cpp_readColumnByName(filename, chpl_arr, colname, numElems);
  }

  int c_getType(const char* filename, const char* colname) {
    return cpp_getType(filename, colname);
  }

  int c_writeColumnToParquet(const char* filename, void* chpl_arr,
                              int colnum, const char* dsetname, int numelems,
                              int rowGroupSize) {
    return cpp_writeColumnToParquet(filename, chpl_arr, colnum, dsetname,
                                    numelems, rowGroupSize);
  }

  const char* c_getVersionInfo(void) {
    return cpp_getVersionInfo();
  }
}
