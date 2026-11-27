pragma Singleton
import QtQuick

// ── datesheet ──
// One list, two readers: the wall's countdown tile and the sheet it opens both
// come from here, so a date is only ever written down once. Each paper carries
// its units; the sheet expands a unit to show the topics inside it.
QtObject {
    id: root

    readonly property var exams: [
        {
            subject: "CSE",
            code: "CSE 101",
            date: "2026-12-07",
            units: [
                {
                    name: "INTRODUCTION TO COMPUTER SCIENCE",
                    topics: [
                        "What is a computer — IPO-storage cycle, five elements",
                        "History of computing devices — Abacus to Mark I",
                        "Generations of computers — 1 to 5, component, memory, languages",
                        "Analog, digital, hybrid computers — meaning and one example",
                        "Types by size — super, mainframe, mini, workstation, micro",
                        "Hardware vs software — system, application, custom, translators",
                        "Operating system — definition, functions, examples",
                        "CPU organisation — ALU, CU, registers, machine cycle",
                        "Registers — PC, IR, MAR, MBR, accumulator",
                        "Memory hierarchy — register, cache, primary, secondary",
                        "RAM vs ROM — volatile, types, uses",
                        "Memory units — bit to TB, the 1024 rule",
                        "Secondary storage — HDD, SSD, pen drive, CD/DVD, tape",
                        "Input and output devices — impact vs non-impact printers",
                        "8085 microprocessor — functional units, addressing modes",
                        "Algorithm — definition, characteristics",
                        "Pseudocode — sum, largest of three, even/odd, average of n",
                        "Flowchart — all symbols, rules, one example",
                        "Programming languages — machine, assembly, high-level",
                        "Compiler vs interpreter vs assembler; linker and loader"
                    ]
                },
                {
                    name: "C BASICS, DECISION MAKING, LOOPS",
                    topics: [
                        "Structure of a C program — the six sections",
                        "Compiling and running — gcc, .c to executable stages",
                        "Tokens — keywords (32), identifiers, constants, operators",
                        "Identifier rules — characters, no keyword, case-sensitive",
                        "Constants — integer, real, character, string, escapes",
                        "Variables — declaration, local, global, static, scope, lifetime",
                        "Data types and sizes — char to double, ranges, format specifiers",
                        "Data type modifiers — short, long, signed, unsigned",
                        "printf / scanf — syntax, field width, return values",
                        "Arithmetic operators — integer vs float division, precedence",
                        "Relational operators — > < >= <= == !=",
                        "Logical operators — && || ! , short-circuit evaluation",
                        "Assignment operators — = and compound += -= *= /=",
                        "Increment / decrement — prefix vs postfix",
                        "Bitwise operators — & | ^ ~ << >>",
                        "Conditional (ternary) operator — cond ? a : b",
                        "Other operators — sizeof, comma, address-of, cast, dot/arrow",
                        "Expression evaluation — precedence and associativity table",
                        "Type conversion — implicit promotion vs casting, truncation",
                        "if and if-else — syntax, dry run, largest of two/three",
                        "Nested if and else-if ladder — grade, eligibility",
                        "switch-case — break, default, fall-through",
                        "while, do-while, for — entry vs exit controlled",
                        "Nested loops — star and number patterns, tables",
                        "break, continue, goto — difference with output",
                        "Loop programs — digits, palindrome, prime, Armstrong, Fibonacci"
                    ]
                },
                {
                    name: "FUNCTIONS, ARRAYS, STRINGS & RECURSION",
                    topics: [
                        "Function basics — need, advantages, library vs user-defined",
                        "Declaration, definition, call — all three parts",
                        "Categories of functions — the four types",
                        "Actual vs formal parameters — correspondence",
                        "return statement — single value, void, returning from main",
                        "Call by value vs call by reference — swap example",
                        "Scope and lifetime — block, function, file scope",
                        "Storage classes — auto, static, extern, register",
                        "Passing arrays to functions — decays to pointer, size separate",
                        "Recursion — base case and recursive case, stack",
                        "Recursion programs — factorial, Fibonacci, digits, GCD, power",
                        "Towers of Hanoi and recursive binary search",
                        "Recursion vs iteration — advantages, stack overflow",
                        "Array basics — same type, contiguous memory",
                        "1-D array — declaration, initialization, index 0 to n-1",
                        "Memory layout and address calculation — base + i × size",
                        "Array operations — read, print, sum, average, min, max",
                        "Searching — linear and binary (sorted array only)",
                        "Sorting — bubble sort and selection sort",
                        "2-D arrays — declaration, initialization, row-major storage",
                        "Matrix programs — addition, transpose, multiplication",
                        "3-D arrays — declaration, initialization, nested loops",
                        "Array programs — frequency, duplicates, merge, second largest",
                        "String as character array — '\\0' terminator, size vs length",
                        "String initialization and I/O — scanf, gets/fgets, puts",
                        "String library functions — strlen, strcpy, strcat, strcmp",
                        "Other string functions — strncpy, strncmp, strrev, strlwr",
                        "String programs without library — length, copy, compare, reverse",
                        "String programs — vowels, word count, case conversion, frequency"
                    ]
                },
                {
                    name: "POINTERS",
                    topics: [
                        "Pointer concept — address vs value, & and *",
                        "Declaration and initialization — type must match, dereferencing",
                        "Pointer types — NULL, wild, dangling, void *",
                        "Pointer arithmetic — p++, p+2, p1-p2, scaling by type size",
                        "Pointers and arrays — a[i] ≡ *(a + i)",
                        "Pointer to pointer — int **p",
                        "Array of pointers vs pointer to array — int *a[5] vs int (*a)[5]",
                        "Pointers and strings — char *s, traversing with a pointer",
                        "Pointers as function arguments — call by reference, swap",
                        "Returning pointers and passing arrays — function returning int *",
                        "Pointers and structures — p->member, (*p).member",
                        "Dynamic memory allocation — malloc, calloc, realloc, free",
                        "Heap vs stack — NULL checks, memory leaks",
                        "Function pointers — declaration, assigning, calling",
                        "const with pointers — pointer to const vs const pointer",
                        "Advantages and disadvantages of pointers",
                        "Common errors — uninitialized dereference, leak, out of bounds"
                    ]
                },
                {
                    name: "ENUM, STRUCTURE, UNION, BITFIELDS & FILES",
                    topics: [
                        "enum — declaration, default values, use in switch",
                        "typedef — syntax, typedef struct shorthand",
                        "Structure basics — definition, initialization, member access",
                        "Nested structures — a.b.c access",
                        "Array of structures — reading and printing records",
                        "Structures and functions — by value vs by pointer, returning",
                        "Pointer to structure — -> operator, dynamic allocation",
                        "Self-referential structure — struct node { int data; ... *next; }",
                        "Bitfields — syntax, width in bits, memory saving, limits",
                        "Union — one member at a time, memory sharing",
                        "Structure vs union — comparison table, sizeof",
                        "Padding, alignment and sizeof a struct",
                        "Applications — records, complex numbers, date, list node",
                        "File concept — stream, text vs binary, FILE *",
                        "fopen modes and fclose — r w a r+ w+ a+, binary modes",
                        "Character and line I/O — fgetc/fputc, fgets/fputs",
                        "Formatted file I/O — fprintf, fscanf",
                        "Block I/O — fread, fwrite for records",
                        "File positioning — feof, fseek, ftell, rewind",
                        "Error handling — NULL check, perror, ferror",
                        "Command line arguments — argc, argv",
                        "File programs — copy, word and line count, append records"
                    ]
                }
            ]
        },
        {
            subject: "APTITUDE",
            date: "2026-12-09",
            units: [
                {
                    name: "PERCENTAGES, RATIO & PROFIT",
                    topics: [
                        "Fraction to percent table",
                        "Successive percentage change",
                        "Population and depreciation problems",
                        "Ratio — simplifying, compound ratio",
                        "Proportion and variation",
                        "Partnership problems",
                        "Cost price, selling price, marked price",
                        "Successive discounts",
                        "False weights and profit on the whole"
                    ]
                },
                {
                    name: "TIME, WORK, SPEED & AVERAGES",
                    topics: [
                        "Work rate and the LCM method",
                        "Efficiency comparison",
                        "Pipes and cisterns",
                        "Work with wages",
                        "Relative speed",
                        "Trains and platforms",
                        "Boats and streams",
                        "Circular tracks",
                        "Average of a series, weighted average",
                        "Alligation rule and replacement of mixtures"
                    ]
                },
                {
                    name: "COUNTING & PROBABILITY",
                    topics: [
                        "Fundamental counting principle",
                        "nPr and nCr",
                        "Circular arrangements",
                        "Permutations with repeated letters",
                        "Classical definition of probability",
                        "Independent and dependent events",
                        "Conditional probability",
                        "Cards, dice and coins"
                    ]
                },
                {
                    name: "REASONING",
                    topics: [
                        "Number and letter series",
                        "Analogies",
                        "Coding-decoding",
                        "Blood relations and directions",
                        "Syllogisms",
                        "Seating arrangement"
                    ]
                },
                {
                    name: "DATA INTERPRETATION",
                    topics: [
                        "Tables",
                        "Bar and line graphs",
                        "Pie charts",
                        "Caselets",
                        "Mixed DI sets under time"
                    ]
                }
            ]
        },
        {
            subject: "PHYSICS",
            code: "FIC 102",
            date: "2026-12-11",
            units: [
                {
                    name: "ELECTROMAGNETISM",
                    topics: [
                        "Electric charge and Coulomb's law — vector form, superposition",
                        "Electric field — point charge, multiple charges, field lines",
                        "Electric flux — Φ = EA cos θ, closed surfaces",
                        "Gauss's law — statement, integral form, Gaussian surface",
                        "Field of an infinite sheet of charge",
                        "Field of a conducting and an insulating sphere",
                        "Electrostatic potential and potential energy",
                        "Relation between E and V — E = −dV/dr, equipotentials",
                        "Parallel plate capacitor — C = ε₀A/d, effect of a dielectric",
                        "Biot–Savart law — field of a straight wire",
                        "Ampere's circuital law — field of an infinite wire",
                        "Magnetic field of a solenoid",
                        "Faraday's law and Lenz's law",
                        "Maxwell's equations (integral form) — all four"
                    ]
                },
                {
                    name: "WAVES AND OPTICAL PHYSICS",
                    topics: [
                        "Electromagnetic waves — transverse, E ⊥ B, c = 1/√(μ₀ε₀)",
                        "EM spectrum — bands by wavelength and their uses",
                        "Wave parameters — y = A sin(kx ± ωt), k, ω, v = λf",
                        "Laws of reflection and refraction — Snell's law",
                        "Superposition principle and interference",
                        "Coherent sources, phase and path difference — Δφ = (2π/λ)Δx",
                        "Constructive and destructive interference conditions",
                        "Young's double slit — fringe width β = λD/d",
                        "Diffraction — Fresnel vs Fraunhofer",
                        "Single-slit diffraction — minima, width of central maximum",
                        "Diffraction grating — d sin θ = nλ, resolving power"
                    ]
                },
                {
                    name: "MODERN PHYSICS",
                    topics: [
                        "Black body radiation — spectral curves, effect of temperature",
                        "Wien's displacement law — λ_max T = b",
                        "Stefan–Boltzmann law — E = σT⁴",
                        "Failure of classical physics — Rayleigh–Jeans, ultraviolet catastrophe",
                        "Planck's quantum hypothesis — E = hν",
                        "Photon concept — E = hc/λ, p = h/λ, E(eV) = 1240/λ(nm)",
                        "Photoelectric effect — setup and observations",
                        "Photoelectric laws and stopping potential — K_max = eV₀",
                        "Einstein's photoelectric equation — hν = φ + K_max",
                        "Drawbacks of wave theory for the photoelectric effect",
                        "de Broglie matter waves — λ = h/p = h/√(2mK)",
                        "Wave-particle duality — evidence for both pictures"
                    ]
                },
                {
                    name: "BASICS OF QUANTUM MECHANICS",
                    topics: [
                        "Wavefunction ψ — meaning, Born interpretation of |ψ|²",
                        "Probability density and normalisation — ∫|ψ|² dV = 1",
                        "Time-dependent Schrödinger equation",
                        "Time-independent Schrödinger equation — Ĥφ = Eφ",
                        "Operators and observables — position, momentum, energy",
                        "Expectation values — ⟨A⟩ = ∫ψ* Â ψ dx",
                        "Heisenberg uncertainty principle — Δx Δp ≥ ħ/2",
                        "Particle in a one-dimensional box — Eₙ = n²h²/8mL²",
                        "Step potential — matching the wavefunction at the boundary",
                        "Potential barrier and tunnelling — T ≈ e^(−2κa), applications",
                        "Quantum harmonic oscillator — Eₙ = (n + ½)ħω, zero-point energy"
                    ]
                },
                {
                    name: "QUANTUM COMPUTATION AND MATERIALS",
                    topics: [
                        "Limitations of classical computation — scaling, Moore's law",
                        "Classical bit vs qubit — difference and physical meaning",
                        "Qubit representation — |ψ⟩ = α|0⟩ + β|1⟩, |α|² + |β|² = 1",
                        "Bloch sphere",
                        "Superposition — how it differs from classical uncertainty",
                        "Entanglement — Bell states, non-classical correlations",
                        "Quantum gates and circuits — Hadamard, CNOT, X/Y/Z",
                        "Algorithms — Deutsch–Jozsa, Grover, Shor",
                        "Quantum materials and physical qubits — superconducting, ion, photonic, spin",
                        "Applications and challenges — decoherence, error correction"
                    ]
                }
            ]
        },
        {
            subject: "CALCULUS",
            code: "FIC 103",
            date: "2026-12-14",
            units: [
                {
                    name: "LIMITS, CONTINUITY, DERIVATIVES & INTEGRALS",
                    topics: [
                        "Functions — domain, co-domain, range",
                        "Graphs of standard functions — linear to trigonometric",
                        "Types of functions — even/odd, monotone, piecewise, composite",
                        "Transformations of graphs — y = af(bx + c) + d",
                        "Limit of a function at a point — left-hand, right-hand, existence",
                        "Limit laws — sum, product, quotient, power, root",
                        "Limit techniques — factorisation, rationalisation, sin x / x, squeeze",
                        "Continuity — the three conditions, continuity on an interval",
                        "Types of discontinuity — removable, jump, infinite",
                        "Derivative at a point — first principle, slope of the tangent",
                        "Differentiation rules — power, product, quotient, chain",
                        "Derivatives of standard functions — polynomial, exp, log, trig, inverse trig",
                        "Implicit differentiation and higher-order derivatives",
                        "Indefinite integral — antiderivative, constant of integration",
                        "Integration techniques — substitution, by parts, partial fractions",
                        "Definite integral — limit of a sum, properties, evaluation",
                        "Fundamental Theorem of Calculus — both parts"
                    ]
                },
                {
                    name: "APPLICATIONS OF CALCULUS (SINGLE VARIABLE)",
                    topics: [
                        "Critical points — f'(x) = 0 or does not exist",
                        "First derivative test — local max, min, neither",
                        "Absolute extrema on a closed interval — critical points and endpoints",
                        "Rolle's Theorem — statement, verification, finding c",
                        "Mean Value Theorem — statement, geometric meaning, finding c",
                        "Increasing and decreasing functions — sign of f'(x)",
                        "Concavity and inflection points — sign of f''(x)",
                        "Second derivative test for local extrema",
                        "Curve sketching — full checklist",
                        "Asymptotes — vertical, horizontal, oblique",
                        "Optimisation word problems — max area, min cost, closest distance",
                        "Related rates and linear approximation"
                    ]
                },
                {
                    name: "SEVERAL VARIABLES: LIMITS, CONTINUITY, PARTIAL DERIVATIVES",
                    topics: [
                        "3-D rectangular coordinate system — octants, plotting points",
                        "Distance formula and equation of a sphere",
                        "Functions of two and three variables — domain, range",
                        "Level curves and contour plots",
                        "Limit of a function of two variables — definition, limit laws",
                        "Two-path test — proving a limit does not exist",
                        "Continuity in higher dimensions",
                        "Partial derivatives — first order, f_x and f_y",
                        "Higher-order and mixed partials — Clairaut's theorem",
                        "Chain rule for functions of several variables",
                        "Directional derivative and gradient — ∇f",
                        "Tangent plane and normal line"
                    ]
                },
                {
                    name: "EXTREMA OF FUNCTIONS OF SEVERAL VARIABLES",
                    topics: [
                        "Local extreme values — critical points, ∇f = 0",
                        "Second derivative (Hessian) test — D = f_xx f_yy − (f_xy)²",
                        "Saddle points — meaning and identification",
                        "Absolute maxima and minima on a closed bounded region",
                        "Lagrange multipliers — ∇f = λ∇g, single constraint",
                        "Applied optimisation — max volume, min surface area, distance"
                    ]
                },
                {
                    name: "MULTIPLE INTEGRALS",
                    topics: [
                        "Double integral over a rectangle — limit of Riemann sums",
                        "Iterated integrals and Fubini's theorem — choosing the order",
                        "Double integrals over general regions — Type I and Type II",
                        "Reversing the order of integration, sketching the region",
                        "Area of bounded regions using double integrals",
                        "Double integrals in polar coordinates — r dr dθ",
                        "Triple integrals in rectangular coordinates",
                        "Volume, mass and centre of mass applications",
                        "Mixed problems — pick the system, set limits, evaluate"
                    ]
                }
            ]
        },
        {
            subject: "EVS",
            date: "2026-12-16",
            units: [
                {
                    name: "ECOSYSTEMS & BIODIVERSITY",
                    topics: [
                        "Ecosystem structure — biotic and abiotic components",
                        "Food chains, food webs and energy flow",
                        "Ecological pyramids and productivity",
                        "Biogeochemical cycles — carbon, nitrogen, water",
                        "Biodiversity — levels and hotspots",
                        "Conservation — in situ and ex situ",
                        "Threats to biodiversity"
                    ]
                },
                {
                    name: "NATURAL RESOURCES",
                    topics: [
                        "Forest resources — uses and deforestation",
                        "Water resources — overuse, dams, conflicts",
                        "Mineral resources and mining impact",
                        "Energy resources — renewable vs non-renewable",
                        "Land resources and desertification",
                        "Food resources and sustainable agriculture"
                    ]
                },
                {
                    name: "POLLUTION",
                    topics: [
                        "Air pollution — sources, effects, control",
                        "Water pollution — sources, BOD/COD, treatment",
                        "Soil pollution and solid waste",
                        "Noise pollution — measurement and limits",
                        "Thermal and radioactive pollution",
                        "E-waste and plastic waste"
                    ]
                },
                {
                    name: "CLIMATE & WASTE MANAGEMENT",
                    topics: [
                        "Greenhouse effect and global warming",
                        "Ozone depletion — mechanism and effects",
                        "Acid rain",
                        "Waste management — reduce, reuse, recycle",
                        "Sanitary landfills and composting",
                        "Case studies"
                    ]
                },
                {
                    name: "POLICY & SUSTAINABLE DEVELOPMENT",
                    topics: [
                        "Environmental legislation — the main acts",
                        "Environmental Impact Assessment",
                        "International agreements and protocols",
                        "Sustainable development goals",
                        "Population growth and the environment",
                        "Role of individuals and NGOs"
                    ]
                }
            ]
        }
    ]

    function dateOf(iso) {
        var p = String(iso).split("-")
        if (p.length !== 3) return new Date()
        return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
    }

    // counted on local midnight, so the number flips with the date rather than
    // with the hour the tile happened to be built
    function daysUntil(iso) {
        var now = new Date()
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        return Math.round((root.dateOf(iso) - today) / 86400000)
    }

    function dayNum(iso) {
        var n = root.dateOf(iso).getDate()
        return n < 10 ? "0" + n : String(n)
    }

    function monthShort(iso) { return Qt.formatDate(root.dateOf(iso), "MMM").toUpperCase() }
    function shortDate(iso) { return Qt.formatDate(root.dateOf(iso), "dd MMM").toUpperCase() }
    function dow(iso) { return Qt.formatDate(root.dateOf(iso), "ddd").toUpperCase() }

    function topicCount(exam) {
        if (!exam || !exam.units) return 0
        var n = 0
        for (var i = 0; i < exam.units.length; i++) n += exam.units[i].topics.length
        return n
    }
}
