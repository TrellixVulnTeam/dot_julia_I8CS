@testset "opendss parser" begin
    @testset "reverse polish notation" begin
        # Examples from OpenDSS manual
        @test isapprox(TPPMs.parse_rpn("2 pi * 60 * .001 *"), 2 * pi * 60 * .001; atol=1e-12)
        @test isapprox(TPPMs.parse_rpn("(14.4 13.8 / sqr 300 *"), (14.4 / 13.8)^2 * 300; atol=1e-12)
        @test isapprox(TPPMs.parse_rpn("24.9 3 sqrt /"), 24.9 / sqrt(3); atol=1e-12)
        @test all(isapprox.(TPPMs.parse_array(Float64, "(\"24.9 3 sqrt /\" \"10 2 *\")"), [24.9 / sqrt(3), 10 * 2.0]; atol=1e-12))

        @test TPPMs.isa_rpn("2 pi * 60 * .001 *")
        @test !TPPMs.isa_rpn("[ 2 10 ]")

        Memento.setlevel!(TESTLOG, "warn")

        @test_warn(TESTLOG, "parse_rpn does not support \"rollup\", \"rolldn\", or \"swap\", leaving as String",
                   TPPMs.parse_rpn("1 2 swap atan2"))

        @test_warn(TESTLOG, "\" 1 2 + - \" is not valid Reverse Polish Notation, leaving as String",
                   TPPMs.parse_rpn(" 1 2 + - "))

        @test_warn(TESTLOG, "\"1 2 3 +\" is not valid Reverse Polish Notation, leaving as String",
                   TPPMs.parse_rpn("1 2 3 +"))

        Memento.setlevel!(TESTLOG, "error")
    end

    @testset "simple generator branch load" begin
        Memento.setlevel!(TESTLOG, "info")

        @test_warn(TESTLOG, "Not all OpenDSS features are supported, currently only minimal support for lines, loads, generators, and capacitors as shunts. Transformers and reactors as transformer branches are included, but value translation is not fully supported.",
                      TPPMs.parse_file("../test/data/opendss/test_simple.dss"))

        Memento.TestUtils.@test_log(TESTLOG, "info", "Calling parse_dss on ../test/data/opendss/test_simple.dss",
                               TPPMs.parse_file("../test/data/opendss/test_simple.dss"))

        Memento.TestUtils.@test_log(TESTLOG, "info", "Done parsing ../test/data/opendss/test_simple.dss",
                               TPPMs.parse_file("../test/data/opendss/test_simple.dss"))

        Memento.setlevel!(TESTLOG, "error")

        dss = TPPMs.parse_dss("../test/data/opendss/test_simple.dss")
        tppm = TPPMs.parse_file("../test/data/opendss/test_simple.dss")

        for (key, len) in zip(["bus", "gen", "branch", "load", "dcline"], [2, 2, 1, 1, 0])
            @test haskey(tppm, key)
            @test length(tppm[key]) == len
        end

        sol = TPPMs.run_tp_opf(tppm, PowerModels.SOCWRPowerModel, ipopt_solver)

        @test sol["status"] == :LocalOptimal
    end

    @testset "parser cases" begin
        Memento.setlevel!(TESTLOG, "info")

        @test_throws(TESTLOG, ErrorException,
                     TPPMs.parse_file("../test/data/opendss/test_simple3.dss"))

        @test_throws(TESTLOG, ErrorException,
                     TPPMs.parse_file("../test/data/opendss/test_simple2.dss"))

        @test_warn(TESTLOG, "Command \"solve\" on line 69 in \"test2_master.dss\" is not supported, skipping.",
                   TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

        @test_warn(TESTLOG, "Command \"show\" on line 71 in \"test2_master.dss\" is not supported, skipping.",
                   TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

        @test_warn(TESTLOG, "reactors as constant impedance elements is not yet supported, treating like line",
                   TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

        @test_warn(TESTLOG, "Rg,Xg are not fully supported",
                   TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

        @test_warn(TESTLOG, "Could not find line \"something\"",
                   TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

       @test_warn(TESTLOG, "The neutral impedance, (rg and xg properties), is ignored; the neutral (for wye and zig-zag windings) is connected directly to the ground.",
                  TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

      @test_warn(TESTLOG, "Only three-phase transformers are supported. The bus specification b7.1 is treated as b7 instead.",
                 TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

        Memento.TestUtils.@test_log(TESTLOG, "info", "`dss_data` has been reset with the \"clear\" command.",
                               TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

        Memento.TestUtils.@test_log(TESTLOG, "info", "Redirecting to file \"test2_Linecodes.dss\"",
                               TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

        Memento.TestUtils.@test_log(TESTLOG, "info", "Compiling file \"test2_Loadshape.dss\"",
                               TPPMs.parse_file("../test/data/opendss/test2_master.dss"))

        Memento.setlevel!(TESTLOG, "error")

        dss = TPPMs.parse_dss("../test/data/opendss/test2_master.dss")
        tppm = TPPMs.parse_file("../test/data/opendss/test2_master.dss")

        @test tppm["name"] == "test2"

        @test length(tppm) == 19 # 1 more entry for transformer dicts
        @test length(dss) == 12

        # 26 buses and not 12, because of internal transformer buses;
        # if rs=0, then 2 extra, else 4 extra
        # tr1:+2(rs=0), tr2:+4, tr3:+2(rs=0), tr4:+4, tr5:+2(rs=0)
        # 16-5+9=20 branches, before one branch per dss transformer, now 1 or 3
        # if rs=0, then 1 extra, else 3 extra
        # tr1:+1(rs=0), tr2:+3, tr3:+1(rs=0), tr4:+3, tr5:+1(rs=0)
        # 10 transformers, 2 per dss transformer
        for (key, len) in zip(["bus", "load", "shunt", "branch", "gen", "dcline", "trans"], [26, 4, 5, 20, 4, 0, 10])
            @test haskey(tppm, key)
            @test length(tppm[key]) == len
        end

        for key in ["loadshape", "linecode", "buscoords", "options", "filename"]
            @test haskey(dss, key)
        end

        len = 0.013516796
        rmatrix=TPPMs.parse_matrix(Float64, "[1.5000  |0.200000  1.50000  |0.250000  0.25000  2.00000  ]") * 3
        xmatrix=TPPMs.parse_matrix(Float64, "[1.0000  |0.500000  0.50000  |0.500000  0.50000  1.000000  ]") * 3
        # added factor 3 to match bug fix in branch parsing, cmatrix
        cmatrix = TPPMs.parse_matrix(Float64, "[8.0000  |-2.00000  9.000000  |-1.75000  -2.50000  8.00000  ]") / 3

        basekv_br3 = tppm["bus"][string(tppm["branch"]["3"]["f_bus"])]["base_kv"]
        @test all(isapprox.(tppm["branch"]["3"]["br_r"].values, rmatrix * len / basekv_br3^2 * tppm["baseMVA"]; atol=1e-6))
        @test all(isapprox.(tppm["branch"]["3"]["br_x"].values, xmatrix * len / basekv_br3^2 * tppm["baseMVA"]; atol=1e-6))
        @test all(isapprox.(tppm["branch"]["3"]["b_fr"].values, diag(basekv_br3^2 / tppm["baseMVA"] * 2.0 * pi * 60.0 * cmatrix * len / 1e9) / 2.0; atol=1e-6))

        for i in 6:7
            basekv_bri = tppm["bus"][string(tppm["branch"]["$i"]["f_bus"])]["base_kv"]
            # added factor 3 to match bug fix in branch parsing
            @test all(isapprox.(tppm["branch"]["$i"]["b_fr"].values, (3.4 * 2.0 + 1.6) / 3.0 * (basekv_bri^2 / tppm["baseMVA"] * 2.0 * pi * 60.0 / 1e9) / 2.0 / 3; atol=1e-6))
        end

        # values were adjusted for the Float16->Float64 change in dss_structs.jl
        # and then also for the new base
        @test all(isapprox.(tppm["branch"]["1"]["br_r"].values.*(115/69)^2, diagm(0 => fill(6.3012e-8, 3)); atol=1e-12))
        @test all(isapprox.(tppm["branch"]["1"]["br_x"].values.*(115/69)^2, diagm(0 => fill(6.3012e-7, 3)); atol=1e-12))

        for k in ["qd", "pd"]
            @test all(isapprox.(tppm["load"]["4"][k].values, tppm["load"]["2"][k].values; atol=1e-12))
        end

        for k in ["gs", "bs"]
            @test all(isapprox.(tppm["shunt"]["2"][k].values, tppm["shunt"]["3"][k].values; atol=1e-12))
            @test all(isapprox.(tppm["shunt"]["4"][k].values, tppm["shunt"]["5"][k].values; atol=1e-12))
        end

        for k in keys(tppm["gen"]["3"])
            if !(k in ["gen_bus", "index", "name", "source_id", "active_phases"])
                if isa(tppm["gen"]["3"][k], PMs.MultiConductorValue)
                    @test all(isapprox.(tppm["gen"]["4"][k].values, tppm["gen"]["3"][k].values; atol=1e-12))
                else
                    @test all(isapprox.(tppm["gen"]["4"][k], tppm["gen"]["3"][k]; atol=1e-12))
                end
            end
        end

        # updated branch numbers; reactors have shifted, added after transformers
        # lines involving former transformer branches have been commented out
        for k in keys(tppm["branch"]["11"])
            if !(k in ["f_bus", "t_bus", "index", "name", "linecode", "source_id", "active_phases"])
                mult = 1.0
                if k in ["br_r", "br_x", "g_fr", "g_to", "b_fr", "b_to"]
                    # compensation for the different voltage base
                    basekv_br3 = tppm["bus"][string(tppm["branch"]["3"]["f_bus"])]["base_kv"]
                    basekv_br8 = tppm["bus"][string(tppm["branch"]["8"]["f_bus"])]["base_kv"]
                    zmult = (basekv_br3/basekv_br8)^2
                    mult = (k in ["br_r", "br_x"]) ? zmult : 1/zmult
                end
                if isa(tppm["branch"]["11"][k], PMs.MultiConductorValue)
                    #@test all(isapprox.(tppm["branch"]["10"][k].values, tppm["branch"]["16"][k].values; atol=1e-12))
                    #@test all(isapprox.(tppm["branch"]["13"][k].values, tppm["branch"]["14"][k].values; atol=1e-12))
                    # compensate for change in base; 3: 41.5, 115.0

                    @test all(isapprox.(tppm["branch"]["3"][k].values.*mult, tppm["branch"]["8"][k].values; atol=1e-12))
                else
                    #@test all(isapprox.(tppm["branch"]["10"][k], tppm["branch"]["11"][k]; atol=1e-12))
                    #@test all(isapprox.(tppm["branch"]["13"][k], tppm["branch"]["14"][k]; atol=1e-12))
                    @test all(isapprox.(tppm["branch"]["3"][k].*mult, tppm["branch"]["8"][k]; atol=1e-12))
                end
            end
        end

        @testset "length units parsing" begin
            @test tppm["branch"]["9"]["length"] == 1000.0 * len
            basekv_br9 = tppm["bus"][string(tppm["branch"]["9"]["f_bus"])]["base_kv"]
            @test all(isapprox.(tppm["branch"]["9"]["br_r"].values, rmatrix * len / basekv_br9^2 * tppm["baseMVA"]; atol=1e-6))
            @test all(isapprox.(tppm["branch"]["9"]["br_x"].values, xmatrix * len / basekv_br9^2 * tppm["baseMVA"]; atol=1e-6))
            # added factor 3 to match bug fix in branch parsing, cmatrix
            @test all(isapprox.(tppm["branch"]["9"]["b_fr"].values, diag(basekv_br9^2 / tppm["baseMVA"] * 2.0 * pi * 60.0 * cmatrix * len / 1e9) / 2.0 / 3; atol=1e-6))
        end

        tppm2 = TPPMs.parse_file("../test/data/opendss/test_simple4.dss")
        @test length(tppm2["bus"]) == 6 # updated nr of buses

        @testset "branches with switches" begin
            @test tppm["branch"]["8"]["switch"]
            @test all([tppm["branch"]["$i"]["switch"] == false for i in 1:6])
        end

        @testset "whitespace before ~" begin
            dss_data = TPPMs.parse_dss("../test/data/opendss/test_transformer_formatting.dss")
            @test dss_data["transformer"][1]["phases"] == "3"
        end

        @testset "storage parse" begin
            tppm_storage = TPPMs.parse_file("../test/data/opendss/case3_balanced_battery.dss")
            for bat in values(tppm_storage["storage"])
                for key in ["energy", "storage_bus", "energy_rating", "charge_rating", "discharge_rating",
                            "charge_efficiency", "discharge_efficiency", "thermal_rating", "qmin", "qmax",
                            "r", "x", "standby_loss", "status", "source_id", "active_phases"]
                    @test haskey(bat, key)
                    if key in ["x", "r", "qmin", "qmax", "thermal_rating"]
                        @test isa(bat[key], PowerModels.MultiConductorVector)
                    end
                end
            end

            @test tppm_storage["storage"]["1"]["source_id"] == "storage.s1" && length(tppm_storage["storage"]["1"]["active_phases"]) == 3
        end

        @testset "source_id check" begin
            @test tppm["shunt"]["1"]["source_id"] == "capacitor.c1" && length(tppm["shunt"]["1"]["active_phases"]) == 3
            @test tppm["shunt"]["4"]["source_id"] == "reactor.reactor3" && length(tppm["shunt"]["4"]["active_phases"]) == 3

            @test tppm["branch"]["1"]["source_id"] == "line.l1" && length(tppm["branch"]["1"]["active_phases"]) == 3
            # transformer is no longer a branch
            @test tppm["trans"]["1"]["source_id"] == "transformer.t4_1"  # winding indicated by _1
            # updated index, reactors shifted
            @test tppm["branch"]["10"]["source_id"] == "reactor.reactor1" && length(tppm["branch"]["10"]["active_phases"]) == 3

            @test tppm["gen"]["1"]["source_id"] == "vsource.sourcebus" && length(tppm["gen"]["1"]["active_phases"]) == 3
            @test tppm["gen"]["2"]["source_id"] == "generator.g1" && length(tppm["gen"]["2"]["active_phases"]) == 3

            source_id = TPPMs.parse_dss_source_id(tppm["load"]["1"])
            @test source_id.dss_type == "load"
            @test source_id.dss_name == "ld1"
            @test all([n in source_id.active_phases for n in 1:2])

            for component_type in ["load", "branch", "shunt", "gen", "storage", "pvsystem"]
                for component in values(get(tppm, component_type, Dict()))
                    @test haskey(component, "source_id")
                    @test haskey(component, "active_phases")
                end
            end
        end
    end

    @testset "2-bus diagonal" begin
        tppm = TPPMs.parse_file("../test/data/opendss/case2_diag.dss")
        @testset "OPF" begin
            @testset "ACP" begin
                sol = TPPMs.run_tp_opf(tppm, PMs.ACPPowerModel, ipopt_solver)

                @test sol["status"] == :LocalOptimal

                @test all(isapprox.(sol["solution"]["bus"]["2"]["vm"].values, 0.984377; atol=1e-4))
                @test all(isapprox.(sol["solution"]["bus"]["2"]["va"].values, TPPMs.wraptopi.([2 * pi / tppm["conductors"] * (1 - c) - deg2rad(0.79) for c in 1:tppm["conductors"]]); atol=deg2rad(0.2)))

                @test isapprox(sum(sol["solution"]["gen"]["1"]["pg"] * sol["solution"]["baseMVA"]), 0.018209; atol=1e-5)
                @test isapprox(sum(sol["solution"]["gen"]["1"]["qg"] * sol["solution"]["baseMVA"]), 0.000208979; atol=1e-5)
            end
        end
    end

    @testset "3-bus balanced" begin
        tppm = TPPMs.parse_file("../test/data/opendss/case3_balanced.dss")
        @testset "OPF" begin
            @testset "ACP" begin
                sol = TPPMs.run_tp_opf(tppm, PMs.ACPPowerModel, ipopt_solver)

                @test sol["status"] == :LocalOptimal

                for (bus, va, vm) in zip(["1", "2", "3"], [0.0, deg2rad(-0.03), deg2rad(-0.07)], [0.9959, 0.986973, 0.976605])
                    @test all(isapprox.(sol["solution"]["bus"][bus]["va"].values, TPPMs.wraptopi.([2 * pi / tppm["conductors"] * (1 - c) + va for c in 1:tppm["conductors"]]); atol=deg2rad(0.01)))
                    @test all(isapprox.(sol["solution"]["bus"][bus]["vm"].values, vm; atol=1e-5))
                end

                @test isapprox(sum(sol["solution"]["gen"]["1"]["pg"] * sol["solution"]["baseMVA"]), 0.018345; atol=1e-6)
                @test isapprox(sum(sol["solution"]["gen"]["1"]["qg"] * sol["solution"]["baseMVA"]), 0.00919404; atol=1.2e-5)
            end
            @testset "SOC" begin
                sol = TPPMs.run_tp_opf(tppm, PMs.SOCWRPowerModel, ipopt_solver)

                @test sol["status"] == :LocalOptimal
            end
            @testset "LDF" begin
                sol = TPPMs.run_tp_opf_bf(tppm, LPLinUBFPowerModel, ipopt_solver)

                @test sol["status"] == :LocalOptimal
                @test isapprox(sum(sol["solution"]["gen"]["1"]["pg"] * sol["solution"]["baseMVA"]), 0.0183456; atol=2e-3)
                @test isapprox(sum(sol["solution"]["gen"]["1"]["qg"] * sol["solution"]["baseMVA"]), 0.00923328; atol=2e-3)
            end
        end
    end

    @testset "3-bus unbalanced" begin
        tppm = TPPMs.parse_file("../test/data/opendss/case3_unbalanced.dss")
        @testset "OPF" begin
            @testset "ACP" begin
                sol = TPPMs.run_tp_opf(tppm, PMs.ACPPowerModel, ipopt_solver)

                @test sol["status"] == :LocalOptimal

                for (bus, va, vm) in zip(["1", "2", "3"],
                                         [0.0, deg2rad.([-0.22, -0.11, 0.12]), deg2rad.([-0.48, -0.24, 0.27])],
                                         [0.9959, [0.980937, 0.98936, 0.987039], [0.963546, 0.981757, 0.976779]])
                    @test all(isapprox.(sol["solution"]["bus"][bus]["va"].values, TPPMs.wraptopi.([2 * pi / tppm["conductors"] * (1 - c) for c in 1:tppm["conductors"]]) .+ va; atol=deg2rad(0.01)))
                    @test all(isapprox.(sol["solution"]["bus"][bus]["vm"].values, vm; atol=1e-5))
                end

                @test isapprox(sum(sol["solution"]["gen"]["1"]["pg"] * sol["solution"]["baseMVA"]), 0.0214812; atol=1e-6)
                @test isapprox(sum(sol["solution"]["gen"]["1"]["qg"] * sol["solution"]["baseMVA"]), 0.00927263; atol=1e-5)
            end
            @testset "SOC" begin
                sol = TPPMs.run_tp_opf(tppm, PMs.SOCWRPowerModel, ipopt_solver)

                @test sol["status"] == :LocalOptimal
            end
            @testset "LDF" begin
                sol = TPPMs.run_tp_opf_bf(tppm, LPLinUBFPowerModel, ipopt_solver)

                @test sol["status"] == :LocalOptimal
                @test isapprox(sum(sol["solution"]["gen"]["1"]["pg"] * sol["solution"]["baseMVA"]), 0.0214812; atol=2e-3)
                @test isapprox(sum(sol["solution"]["gen"]["1"]["qg"] * sol["solution"]["baseMVA"]), 0.00927263; atol=2e-3)
            end
        end
    end

    @testset "3-bus unbalanced isc" begin
        tppm = TPPMs.parse_file("../test/data/opendss/case3_balanced_isc.dss")
        sol = TPPMs.run_tp_opf(tppm, PMs.ACPPowerModel, ipopt_solver)

        @test sol["status"] == :LocalOptimal
        @test isapprox(sol["objective"], 0.0182769; atol = 1e-4)
    end

    @testset "3-bus balanced pv" begin
        Memento.setlevel!(TESTLOG, "warn")
        @test_warn(TESTLOG, "Converting PVSystem \"pv1\" into generator with limits determined by OpenDSS property 'kVA'",
                   TPPMs.parse_file("../test/data/opendss/case3_balanced_pv.dss"))
        Memento.setlevel!(TESTLOG, "error")

        tppm = TPPMs.parse_file("../test/data/opendss/case3_balanced_pv.dss")

        @test length(tppm["gen"]) == 2
        @test all(tppm["gen"]["2"]["qmin"] .== -tppm["gen"]["2"]["qmax"])
        @test all(tppm["gen"]["2"]["pmax"] .== tppm["gen"]["2"]["qmax"])
        @test all(tppm["gen"]["2"]["pmin"].values .== 0.0)

        sol = TPPMs.run_tp_opf(tppm, PMs.ACPPowerModel, ipopt_solver)

        @test sol["status"] == :LocalOptimal
        @test sum(sol["solution"]["gen"]["1"]["pg"] * sol["solution"]["baseMVA"]) < 0.0
        @test sum(sol["solution"]["gen"]["1"]["qg"] * sol["solution"]["baseMVA"]) < 0.0
        @test isapprox(sum(sol["solution"]["gen"]["2"]["pg"] * sol["solution"]["baseMVA"]), 0.018345; atol=1e-4)
        @test isapprox(sum(sol["solution"]["gen"]["2"]["qg"] * sol["solution"]["baseMVA"]), 0.00919404; atol=1e-4)
    end

    @testset "3-bus unbalanced single-phase pv" begin
        tppm = TPPMs.parse_file("../test/data/opendss/case3_unbalanced_1phase-pv.dss")
        sol = TPPMs.run_tp_opf(tppm, PMs.ACPPowerModel, ipopt_solver)

        @test sol["status"] == :LocalOptimal

        @test isapprox(sum(sol["solution"]["gen"]["1"]["pg"] * sol["solution"]["baseMVA"]), 0.0196116; atol=1e-3)
        @test isapprox(sum(sol["solution"]["gen"]["1"]["qg"] * sol["solution"]["baseMVA"]), 0.00923107; atol=1e-3)

        @test all(sol["solution"]["gen"]["2"]["pg"][2:3] .== 0.0)
        @test all(sol["solution"]["gen"]["2"]["qg"][2:3] .== 0.0)
    end
end
