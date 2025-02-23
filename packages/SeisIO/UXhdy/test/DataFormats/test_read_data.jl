nx = 256
os = 3
buf = getfield(BUF, :buf)
x = getfield(BUF, :int32_buf)
nx_add = 1400000
nx_new = 36000
pref = path * "/SampleFiles/"
cfile = pref * "Restricted/03_02_27_20140927.sjis.ch"
files = String[ "99011116541W"                "uw"            "_"
                "test_PASSCAL.segy"           "passcal"       "pa-full"
                "test_PASSCAL.segy"           "passcal"       "passcal"
                "one_day.sac"                 "sac"           "_"
                "one_day.mseed"               "mseed"         "_"
                "Restricted/2014092709*.cnt"  "win32"         "win"
                "0215162000.c00"              "lennasc"       "_"
                "geocsv_slist.csv"            "geocsv.slist"  "_"
                "Restricted/SHW.UW.mseed"     "mseed"         "lo-mem"
                "Restricted/test_rev_1.segy"  "segy"          "full"
                "Restricted/test_rev_1.segy"  "segy"          "_"
                "test_be.sac"                 "sac"           "full"
                "test_be.sac"                 "sac"           "_"
                "FDSNWS.IRIS.geocsv"          "geocsv"        "_"      ]

checkbuf_8!(buf, 65536)
checkbuf_8!(buf, 4*(os + nx))
checkbuf!(x, os + nx)

# test fillx_i16_le!
y = rand(Int16, nx)
copyto!(buf, 1, reinterpret(UInt8, y), 1, 2*nx)
fillx_i16_le!(x, buf, nx, os)
@test x[1+os:nx+os] == y

# test fillx_i32_le!
y = rand(Int32, nx)
copyto!(buf, 1, reinterpret(UInt8, y), 1, 4*nx)
fillx_i32_le!(x, buf, nx, os)
@test x[1+os:nx+os] == y

fillx_i32_be!(x, buf, nx, os)
@test x[1+os:nx+os] == bswap.(y)

# Do not run on Appveyor; it can't access restricted files, so this breaks
if Sys.iswindows() == false
  printstyled("  read_data\n", color=:light_green)
  nf = size(files,1)
  for n = 1:nf
    fname = pref * files[n,1]
    fwild = fname[1:end-2] * "*"
    f_call = files[n,2]
    opt = files[n,3]
    printstyled(string("    ", n, "/", nf, " ", f_call, "\n"), color=:light_green)
    if opt == "pa-full"
      S = read_data("passcal", fname, full=true)
      S = read_data("passcal", fwild, full=true)
    elseif opt == "win"
      S = read_data(f_call, fwild, cf=cfile)
    elseif opt == "slist"
      S = read_data("geocsv.slist", fname, tspair=false)
      S = read_data("geocsv.slist", fwild, tspair=false)
    elseif opt == "lo-mem"
      S = read_data(f_call, fname, nx_new=nx_new, nx_add=nx_add)
      S = read_data(f_call, fwild, nx_new=nx_new, nx_add=nx_add)
    elseif opt == "full"
      S = read_data(f_call, fname, full=true)
      S = read_data(f_call, fwild, full=true)
    else
      S = read_data(f_call, fname)
      if f_call == "uw"
        fwild = fname[1:end-3]*"*"*"W"
      end
      S = read_data(f_call, fwild)
    end
  end
end

@test_throws ErrorException read_data("deez", "nutz.sac")
