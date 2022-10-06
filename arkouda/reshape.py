from arkouda.pdarrayclass import *
from typing import cast, List, Sequence
import itertools
import numpy as np # type: ignore
import pandas as pd # type: ignore
from typing import cast, Iterable, Optional, Union
from typeguard import typechecked
from arkouda.client import generic_msg
from arkouda.dtypes import NUMBER_FORMAT_STRINGS, float64, int64, \
     DTypes, isSupportedInt, isSupportedNumber, NumericDTypes, SeriesDTypes,\
    int_scalars, numeric_scalars, get_byteorder, get_server_byteorder
from arkouda.dtypes import dtype as akdtype
from arkouda.pdarrayclass import pdarray, create_pdarray
from arkouda.pdarray2dclass import create_pdarray2D
from arkouda.pdarray3dclass import create_pdarray3D
from arkouda.pdarray4dclass import create_pdarray4D
from arkouda.strings import Strings
from arkouda.logger import getArkoudaLogger

from typeguard import typechecked
import json
import numpy as np # type: ignore
from arkouda.client import generic_msg
from arkouda.dtypes import dtype, DTypes, resolve_scalar_dtype, \
     translate_np_dtype, NUMBER_FORMAT_STRINGS, \
     int_scalars, numeric_scalars, numeric_and_bool_scalars, numpy_scalars, get_server_byteorder
from arkouda.dtypes import int64 as akint64
from arkouda.dtypes import str_ as akstr_
from arkouda.dtypes import bool as npbool
from arkouda.dtypes import isSupportedInt
from arkouda.logger import getArkoudaLogger
from arkouda.infoclass import list_registry, information, pretty_print_information

logger = getArkoudaLogger(name='reshape')

__all__ = ['reshape', 'flatten']

def reshape(obj : pdarray, newshape : Union[numeric_scalars, tuple]) -> pdarray:
    """
    Reshape
    Parameters
    ----------
    obj : pdarray
        The pdarray to reshape.
    newshape : Union[numeric_scalars, tuple]
        The shape to resize the array to. This could be anything from a scalar to
        a 4D array.
    Returns
    -------
    pdarray
        A new pdarray containing the same elements of `obj`, but with a
        new domain.
    Raises
    ------
    ValueError
        Raised if `newshape` contains more than 4 elements or the supplied
        new shape can't fit all elements of original array.
    Notes
    -----
    Setting one of the values in `newshape` to `-1` will infer the correct
    length to pass to ensure that the new array fits the correct number of
    elements.
    Examples
    --------
    >>> a = ak.array([1,2,3,4])
    >>> ak.reshape(a, (2,2))
    array([[1, 2],
           [3, 4]])
    >>> ak.reshape(a, (-1,1))
    array([[1],
           [2],
           [3],
           [4]]))
    """
    initial_size = obj.size

    if isinstance(newshape, tuple):
        if len(newshape) > 4:
            raise ValueError("more than 4 dimensions provided for newshape: {}".format(len(newshape)))

        if len(newshape) == 2:
          m = newshape[0]
          n = newshape[1]

          if m == -1:
            m = int(initial_size/n)
          if n == -1:
            n = int(initial_size/m)
          if m*n != initial_size:
            raise ValueError("size mismatch, 2D dimensions must result in array of equivalent size: {} != {}".format(obj.size,m*n))
#          rep_msg = generic_msg(cmd='reshape2D', args=f"{obj.name} {m} {n}")
          rep_msg = generic_msg(cmd='reshape2D', args={"name": obj.name, "m": m, "n": n})
          return create_pdarray2D(rep_msg)
        elif len(newshape) == 3:
          m = newshape[0]
          n = newshape[1]
          p = newshape[2]

          newsize = 1
          final_shape = []
          for dim in newshape:
            newsize *= dim
          for dim in newshape:
            if dim == -1:
              tmp = int(-initial_size / newsize)
              final_shape.append(tmp)
              newsize *= tmp
            else:
              final_shape.append(dim)
          if np.prod(final_shape) != initial_size:
            raise ValueError("size mismatch, 3D dimensions must result in array of equivalent size: {} != {}".format(initial_size,np.prod(final_shape)))
#          rep_msg = generic_msg(cmd='reshape3D', args=f"{obj.name} {m} {n} {p}")
          rep_msg = generic_msg(cmd='reshape2D', args={"name": obj.name, "m": m, "n": n, "p": p})
          return create_pdarray3D(rep_msg) 
        elif len(newshape) == 4:
          m = newshape[0]
          n = newshape[1]
          p = newshape[2]
          q = newshape[3]

          newsize = 1
          final_shape = []
          for dim in newshape:
            newsize *= dim
          for dim in newshape:
            if dim == -1:
              tmp = int(-initial_size / newsize)
              final_shape.append(tmp)
              newsize *= tmp
            else:
              final_shape.append(dim)
          if np.prod(final_shape) != initial_size:
            raise ValueError("size mismatch, 4D dimensions must result in array of equivalent size: {} != {}".format(initial_size,np.prod(final_shape)))
#          rep_msg = generic_msg(cmd='reshape4D', args=f"{obj.name} {m} {n} {p} {q}")
          rep_msg = generic_msg(cmd='reshape2D', args={"name": obj.name, "m": m, "n": n, "p": p, "q": q})
          return create_pdarray4D(rep_msg)           

    else:
        if newshape == -1 or newshape == initial_size:
#            rep_msg = generic_msg(cmd='reshape1D', args=f"{obj.name}")
          rep_msg = generic_msg(cmd='reshape1D', args={"name": obj.name})
          return create_pdarray2D(rep_msg)
        else:
          raise ValueError("size mismatch, resizing to 1D must either be -1 or array size: provided: {} array size: {}".format(newshape, obj.size))

def flatten(obj : pdarray) -> pdarray:
    """
    Flatten
    Parameters
    ----------
    obj : pdarray
        The pdarray to flatten.
    Returns
    -------
    pdarray
        A new pdarray containing the same elements of `obj`, but with a
        new domain.
    """

#    rep_msg = generic_msg(cmd='reshape1D', args=f"{obj.name}")
    rep_msg = generic_msg(cmd='reshape1D', args={"name": obj.name})
    return create_pdarray2D(rep_msg)
