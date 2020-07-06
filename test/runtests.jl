using CommonRLInterface
using Test

@testset "from README" begin
    mutable struct LQREnv <: AbstractEnv
        s::Float64
    end

    function CommonRLInterface.reset!(m::LQREnv)
        m.s = 0.0
    end

    CommonRLInterface.actions(m::LQREnv) = (-1.0, 0.0, 1.0)

    function CommonRLInterface.act!(m::LQREnv, a)
        r = -m.s^2 - a^2
        m.s = m.s + a + randn()
        return r, false, NamedTuple()
    end

    CommonRLInterface.observe(m::LQREnv) = m.s

    # from version 0.2 on, you can implement optional functions like this:
    # @provide CommonRLInterface.clone(m::LQREnv) = LQREnv(m.s)

    env = LQREnv(0.0)
    done = false
    reset!(env)
    acts = actions(env)
    rsum = 0.0
    step = 1
    while !done && step <= 10
        r, done, info = act!(env, rand(acts)) 
        r += rsum
        step += 1
    end
    @show rsum
end

# a reference MarkovEnv
mutable struct MyEnv <: AbstractMarkovEnv
    state::Int
end
MyEnv() = MyEnv(1)
function CommonRLInterface.reset!(env::MyEnv)
    env.state = 1
end
CommonRLInterface.actions(env::MyEnv) = (-1, 0, 1)
CommonRLInterface.observe(env::MyEnv) = env.state
function CommonRLInterface.act!(env::MyEnv, a)
    env.state = clamp(env.state + a, 1, 10)
    return -o^2, false, NamedTuple()
end
env = MyEnv(1)

# a reference ZeroSumEnv
mutable struct MyGame <: AbstractZeroSumEnv
    state::Int
end
MyGame() = MyGame(1)
function CommonRLInterface.reset!(env::MyGame)
    env.state = 1
end
CommonRLInterface.actions(env::MyGame) = (-1, 1)
CommonRLInterface.observe(env::MyGame) = env.state
function CommonRLInterface.act!(env::MyGame, a)
    env.state = clamp(env.state + a, 1, 10)
    return -o^2, false, NamedTuple()
end
CommonRLInterface.player(env::MyGame) = 1 + iseven(env.state)
game = MyGame()

function f end

# h needs to be out here for the inference to work for some reason
function h(x)
    if provided(f, x)
        return f(x)
    else
        return sin(x)
    end
end

@testset "providing" begin
    global f, h

    @test_throws MethodError f(2)
    @test provided(f, 2) == false

    @provide f(x::Int) = x^2

    @test provided(f, 2) == true
    @test provided(f, Tuple{Int}) == true
    @test f(2) == 4

    @provide function f(s::String)
        s*"^2"
    end
    @test provided(f, "2") == true
    @test provided(f, Tuple{String}) == true
    @test f("2") == "2^2"

    @test provided(f, 2.0) == false
    @test provided(f, Tuple{Float64}) == false

    @test @inferred(h(2)) == f(2)::Int

    g() = nothing

    @provide g(a, b::AbstractVector{<:Number}) = a.*b

    @test provided(g, 1, [1.0]) == true
    @test provided(g, typeof((1, [1.0]))) == true
    @test g(1, [1.0]) == [1.0]
    @test provided(g, 1, ["one"]) == false

    @test provided(reset!, MyEnv())
    @test !provided(clone, MyEnv())
    @test !provided(player, MyEnv())
    @test !provided(actions, MyEnv(), 1)

    @test provided(player, MyGame())
end

@testset "environment" begin
    Base.:(==)(a::MyEnv, b::MyEnv) = a.state == b.state
    Base.hash(x::MyEnv, h=zero(UInt)) = hash(x.state, h)
    @provide CommonRLInterface.clone(env::MyEnv) = MyEnv(env.state)
    @test provided(clone, env)
    @test clone(env) == MyEnv(1)

    @provide CommonRLInterface.render(env::MyEnv) = "MyEnv with state $(env.state)"
    @test provided(render, MyEnv(1))
    @test render(MyEnv(1)) == "MyEnv with state 1"
end

@testset "spaces" begin
    @provide CommonRLInterface.valid_actions(env::MyEnv) = (0, 1)
    @test provided(valid_actions, env)
    @test issubset(valid_actions(env), actions(env))

    @provide CommonRLInterface.valid_action_mask(env::MyEnv) = [false, true, true]
    @test provided(valid_action_mask, env)
    va = valid_actions(env)
    vam = actions(env)[valid_action_mask(env)]
    @test issubset(va, vam)
    @test issubset(vam, va)

    @provide CommonRLInterface.observations(env::MyEnv) = 1:10
    @test provided(observations, env)
    @test observations(env) == 1:10
end
