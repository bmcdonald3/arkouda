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

logger = getArkoudaLogger(name='pdarrayclass')

__all__ = ['array3D', 'randint3D'] #, 'reshape']

class pdarray3D(pdarray):
    objtype = 'pdarray3D'

    def __getitem__(self, key):
        if np.isscalar(key) and resolve_scalar_dtype(key) == 'int64':
            orig_key = key
            if key < 0:
                # Interpret negative key as offset from end of array
                key += self.size
            if (key >= 0 and key < self.size):
                repMsg = generic_msg(cmd="[int3d]", args={"name": self.name, "key": key})
                return create_pdarray(repMsg)
            else:
                raise IndexError("[int] {} is out of bounds with size {}".format(orig_key,self.size))
        raise TypeError("Unhandled key type: {} ({})".format(key, type(key)))

    def _binop(self, other, op : str) -> pdarray:
        """
        Executes binary operation specified by the op string
        Parameters
        ----------
        other : pdarray
        The pdarray upon which the binop is to be executed
        op : str
        The binop to be executed
        Returns
        -------
        pdarray
        A pdarray3D encapsulating the binop result
        Raises
        ------
        ValueError
        Raised if the op is not within the pdarray.BinOps set, or if the
        pdarray sizes don't match
        TypeError
        Raised if other is not a pdarray or the pdarray.dtype is not
        a supported dtype
        """
        # For pdarray subclasses like ak.Datetime and ak.Timedelta, defer to child logic
        if type(other) != pdarray3D:
            return NotImplemented
        if op not in self.BinOps:
            raise ValueError("bad operator {}".format(op))
        # pdarray binop pdarray
        if isinstance(other, pdarray3D):
            if self.size != other.size:
                raise ValueError("size mismatch {} {}".format(self.size,other.size))
            cmd = "binopvv3d"
            repMsg = generic_msg(cmd=cmd, args={"op": op, "a": self.name, "b": other.name})
            return create_pdarray3D(repMsg)
        # pdarray binop scalar
        dt = resolve_scalar_dtype(other)
        if dt not in DTypes:
            raise TypeError("Unhandled scalar type: {} ({})".format(other, 
                                                                type(other)))

def create_pdarray3D(repMsg : str) -> pdarray3D:
    try:
        fields = repMsg.split()
        name = fields[1]
        mydtype = fields[2]
        size = int(fields[3])
        ndim = int(fields[4])
        # remove comma from 1 tuple with trailing comma
        if fields[5][len(fields[5]) - 2] == ",":
            fields[5] = fields[5].replace(",", "")
        shape = [int(el) for el in fields[5][1:-1].split(',')]
        itemsize = int(fields[6])
    except Exception as e:
        raise ValueError(e)
    logger.debug(("created Chapel array with name: {} dtype: {} size: {} ndim: {} shape: {} " +
                  "itemsize: {}").format(name, mydtype, size, ndim, shape, itemsize))
    return pdarray3D(name, dtype(mydtype), size, ndim, shape, itemsize)

def array3D(val, m, n, p, dtype: Union[np.dtype, type, str] = float64) -> Union[pdarray, Strings]:
    """
    Generate a 3D pdarray that is of size `m x n x p` and initialized to the
    value `val`.
    Parameters
    ----------
    val : numeric_and_bool_scalars
        The value to initialize all elements of the 3D array to
    m : int_scalars
        The `m` dimension of the array to create
    n : int_scalars
        The `n` dimension of the array to create
    p : int_scalars
        The `p` dimension of the array to create
    dtype: all_scalars
        Resulting array type, default float64
    Returns
    -------
    pdarray
        array of the requested size (m,n) and dtype filled with `fill_value`
    Raises
    ------
    TypeError
        Raised if a is not a pdarray, np.ndarray, or Python Iterable such as a
        list, array, tuple, or deque, or if the supplied dtype is not supported,
        or if the size parameter is neither an int nor a str that is parseable to an int.
    See Also
    --------
    ak.array
    Notes
    -----
    We cannot pass the binary data back for this function since it is optional
    on the server side, which means that its signature must be identical to 
    the regular Arkouda message. Could possibly add a second map that was like
    "arrayCreationMap" or something that handled signatures of that type.    
    Examples
    --------
    >>> ak.array3D(5, 2, 2, 2)
    array([[[5, 5],
            [5, 5]],
            [[5, 5],
            [5, 5]]] )
    
    """
    args = ""
    from arkouda.client import maxTransferBytes
    # Only rank 3 arrays currently supported
    rep_msg = generic_msg(cmd='array3d', args={"dtype": cast(np.dtype, dtype).name, "val": val, "m": m, "n": n, "p": p})
    return create_pdarray3D(rep_msg)


def randint3D(low : numeric_scalars, high : numeric_scalars, 
              m : int_scalars, n : int_scalars, p : int_scalars, dtype=int64, seed : int_scalars=None) -> pdarray:
    """
    Generate a 3 dimensional pdarray of randomized int, float, or bool values in a 
    specified range bounded by the low and high parameters.
    Parameters
    ----------
    low : numeric_scalars
        The low value (inclusive) of the range
    high : numeric_scalars
        The high value (exclusive for int, inclusive for float) of the range
    m :  int_scalars
        The `m` dimension of the array to create
    n : int_scalars
        The `n` dimension of the array to create
    p : int_scalars
        The `p` dimension of the array to create
    dtype : Union[int64, float64, bool]
        The dtype of the array
    seed : int_scalars
        Index for where to pull the first returned value
        
    Returns
    -------
    pdarray
        Values drawn uniformly from the specified range having the desired dtype
        
    Raises
    ------
    TypeError
        Raised if dtype.name not in DTypes, size is not an int, low or high is
        not an int or float, or seed is not an int
    ValueError
        Raised if size < 0 or if high < low
    Notes
    -----
    Calling randint with dtype=float64 will result in uniform non-integral
    floating point values.
    Examples
    --------
    >>> ak.randint3D(0, 10, 2, 2, 2)
    array([[[3, 6],
            [8, 4]],
            [[7, 2],
            [1, 5]]])
    """
    if high < low:
        raise ValueError("size must be > 0 and high > low")
    dtype = akdtype(dtype) # normalize dtype
    # check dtype for error
    if dtype.name not in DTypes:
        raise TypeError("unsupported dtype {}".format(dtype))
    lowstr = NUMBER_FORMAT_STRINGS[dtype.name].format(low)
    highstr = NUMBER_FORMAT_STRINGS[dtype.name].format(high)

    repMsg = generic_msg(cmd='randint3d', args={"dtype": cast(np.dtype, dtype).name, "low": lowstr, "high": highstr, "m": m, "n": n, "p": p, "seed": seed})
    return create_pdarray3D(repMsg)
