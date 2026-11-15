"""Pure-Python reader for NetCDF classic files (CDF-1 and CDF-2), uncompressed, no record variables.

Only what the map tools need: list the variables, read a rectangular block of one variable as floats (scale and
fill applied), and read a 1-D coordinate axis. No third-party packages (the project venv has no netCDF4 or scipy).
Format reference: the NetCDF classic file format (all integers and floats are big-endian).
"""

import math
import struct

NC_DIMENSION = 0x0A
NC_VARIABLE = 0x0B
NC_ATTRIBUTE = 0x0C

# type code -> (struct code, size in bytes, name)
_TYPES = {
    1: ("b", 1, "byte"),
    2: ("c", 1, "char"),
    3: ("h", 2, "short"),
    4: ("i", 4, "int"),
    5: ("f", 4, "float"),
    6: ("d", 8, "double"),
}


class NetCDFError(Exception):
    pass


class Variable:
    def __init__(self, name: str, dim_ids: list, attrs: dict, type_code: int, begin: int) -> None:
        self.name = name
        self.dim_ids = dim_ids
        self.attrs = attrs
        self.type_code = type_code
        self.begin = begin
        self.shape: list = []


class NetCDFClassic:
    """Opens a file and keeps the header. The data is read on demand from the file."""

    def __init__(self, path: str) -> None:
        self.path = path
        self._f = open(path, "rb")
        self._pos = 0
        magic = self._f.read(4)
        if magic[:3] != b"CDF":
            raise NetCDFError("%s is not a NetCDF classic file" % path)
        version = magic[3]
        if version not in (1, 2):
            raise NetCDFError("%s: NetCDF version %d is not classic (CDF-1 or CDF-2)" % (path, version))
        self._offset_size = 4 if version == 1 else 8
        self._pos = 4
        self.numrecs = self._int()
        self.dims: list = []  # (name, length); length 0 = unlimited
        self.global_attrs: dict = {}
        self.variables: dict = {}
        self._read_dims()
        self.global_attrs = self._read_att_list()
        self._read_vars()
        for var in self.variables.values():
            var.shape = [self.dims[d][1] for d in var.dim_ids]
            if any(self.dims[d][1] == 0 for d in var.dim_ids):
                raise NetCDFError("%s: record (unlimited) variables are not supported" % var.name)

    def close(self) -> None:
        self._f.close()

    def __enter__(self) -> "NetCDFClassic":
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    # ----- header reading -----------------------------------------------------------------------------------

    def _read(self, n: int) -> bytes:
        self._f.seek(self._pos)
        data = self._f.read(n)
        if len(data) != n:
            raise NetCDFError("%s: header truncated" % self.path)
        self._pos += n
        return data

    def _int(self) -> int:
        return struct.unpack(">i", self._read(4))[0]

    def _name(self) -> str:
        n = self._int()
        raw = self._read(n)
        self._pos += (4 - n % 4) % 4
        return raw.decode("utf-8")

    def _read_dims(self) -> None:
        tag = self._int()
        count = self._int()
        if tag == 0 and count == 0:
            return
        if tag != NC_DIMENSION:
            raise NetCDFError("%s: expected a dimension list" % self.path)
        for _ in range(count):
            name = self._name()
            self.dims.append((name, self._int()))

    def _read_att_list(self) -> dict:
        tag = self._int()
        count = self._int()
        attrs: dict = {}
        if tag == 0 and count == 0:
            return attrs
        if tag != NC_ATTRIBUTE:
            raise NetCDFError("%s: expected an attribute list" % self.path)
        for _ in range(count):
            name = self._name()
            type_code = self._int()
            n = self._int()
            code, size, _tn = _TYPES[type_code]
            raw = self._read(n * size)
            self._pos += (4 - (n * size) % 4) % 4
            if code == "c":
                attrs[name] = raw.decode("utf-8", "replace")
            else:
                values = list(struct.unpack(">%d%s" % (n, code), raw))
                attrs[name] = values[0] if n == 1 else values
        return attrs

    def _read_vars(self) -> None:
        tag = self._int()
        count = self._int()
        if tag == 0 and count == 0:
            return
        if tag != NC_VARIABLE:
            raise NetCDFError("%s: expected a variable list" % self.path)
        for _ in range(count):
            name = self._name()
            ndims = self._int()
            dim_ids = [self._int() for _ in range(ndims)]
            attrs = self._read_att_list()
            type_code = self._int()
            self._int()  # vsize (padded size per variable): not needed for non-record data
            if self._offset_size == 4:
                begin = self._int()
            else:
                begin = struct.unpack(">q", self._read(8))[0]
            self.variables[name] = Variable(name, dim_ids, attrs, type_code, begin)

    # ----- data reading -------------------------------------------------------------------------------------

    def _fill_and_scale(self, var: Variable) -> tuple:
        scale = float(var.attrs.get("scale_factor", 1.0))
        offset = float(var.attrs.get("add_offset", 0.0))
        fills = []
        for key in ("_FillValue", "missing_value"):
            if key in var.attrs:
                value = var.attrs[key]
                fills.append(float(value[0] if isinstance(value, list) else value))
        return scale, offset, fills

    def shape_of(self, name: str) -> tuple:
        return tuple(self.variables[name].shape)

    def read_block(self, name: str, row0: int, row1: int, col0: int, col1: int) -> list:
        """Rows row0..row1-1 and columns col0..col1-1 of a 2-D variable, as lists of floats (NaN for fill)."""
        var = self.variables[name]
        if len(var.shape) != 2:
            raise NetCDFError("%s is not 2-D" % name)
        nrows, ncols = var.shape
        if not (0 <= row0 < row1 <= nrows and 0 <= col0 < col1 <= ncols):
            raise NetCDFError("%s: block outside the variable" % name)
        code, size, _tn = _TYPES[var.type_code]
        scale, offset, fills = self._fill_and_scale(var)
        width = col1 - col0
        out = []
        for r in range(row0, row1):
            start = var.begin + (r * ncols + col0) * size
            self._f.seek(start)
            raw = self._f.read(width * size)
            if len(raw) != width * size:
                raise NetCDFError("%s: data truncated" % name)
            values = struct.unpack(">%d%s" % (width, code), raw)
            line = []
            for v in values:
                fv = float(v)
                if fv in fills:
                    line.append(math.nan)
                else:
                    line.append(fv * scale + offset)
            out.append(line)
        return out

    def read_axis(self, name: str) -> list:
        """A 1-D coordinate variable as a list of floats."""
        var = self.variables[name]
        if len(var.shape) != 1:
            raise NetCDFError("%s is not 1-D" % name)
        code, size, _tn = _TYPES[var.type_code]
        n = var.shape[0]
        self._f.seek(var.begin)
        raw = self._f.read(n * size)
        return [float(v) for v in struct.unpack(">%d%s" % (n, code), raw)]
