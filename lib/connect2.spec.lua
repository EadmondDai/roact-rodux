return function()
	local connect2 = require(script.Parent.connect2)

	local StoreProvider = require(script.Parent.StoreProvider)

	local Roact = require(script.Parent.Parent.Roact)
	local Rodux = require(script.Parent.Parent.Rodux)

	local function noop()
		return nil
	end

	local function NoopComponent()
		return nil
	end

	local function countReducer(state, action)
		state = state or 0

		if action.type == "increment" then
			return state + 1
		end

		return state
	end

	local reducer = Rodux.combineReducers({
		count = countReducer,
	})

	describe("Argument validation", function()
		it("should accept no arguments", function()
			connect2()
		end)

		it("should accept one function", function()
			connect2(noop)
		end)

		it("should accept two functions", function()
			connect2(noop, noop)
		end)

		it("should accept only the second function", function()
			connect2(nil, function() end)
		end)

		it("should throw if not passed a component", function()
			local selector = function(store)
				return {}
			end

			expect(function()
				connect2(selector)(nil)
			end).to.throw()
		end)
	end)

	it("should throw if not mounted under a StoreProvider", function()
		local ConnectedSomeComponent = connect2()(NoopComponent)

		expect(function()
			Roact.reify(Roact.createElement(ConnectedSomeComponent))
		end).to.throw()
	end)

	it("should accept a higher-order function mapStateToProps", function()
		local function mapStateToProps()
			return function(state)
				return {
					count = state.count,
				}
			end
		end

		local ConnectedSomeComponent = connect2(mapStateToProps)(NoopComponent)

		local store = Rodux.Store.new(reducer)
		local tree = Roact.createElement(StoreProvider, {
			store = store,
		}, {
			someComponent = Roact.createElement(ConnectedSomeComponent),
		})

		local handle = Roact.reify(tree)

		Roact.teardown(handle)
	end)

	it("should not accept a higher-order mapStateToProps that returns a non-table value", function()
		local function mapStateToProps()
			return function(state)
				return "nope"
			end
		end

		local ConnectedSomeComponent = connect2(mapStateToProps)(NoopComponent)

		local store = Rodux.Store.new(reducer)
		local tree = Roact.createElement(StoreProvider, {
			store = store,
		}, {
			someComponent = Roact.createElement(ConnectedSomeComponent),
		})

		expect(function()
			Roact.reify(tree)
		end).to.throw()
	end)

	it("should not accept a mapStateToProps that returns a non-table value", function()
		local function mapStateToProps()
			return "nah"
		end

		local ConnectedSomeComponent = connect2(mapStateToProps)(NoopComponent)

		local store = Rodux.Store.new(reducer)
		local tree = Roact.createElement(StoreProvider, {
			store = store,
		}, {
			someComponent = Roact.createElement(ConnectedSomeComponent),
		})

		expect(function()
			Roact.reify(tree)
		end).to.throw()
	end)

	it("should abort renders when mapStateToProps returns the same data", function()
		local function mapStateToProps(state)
			return {
				count = state.count,
			}
		end

		local renderCount = 0
		local function SomeComponent(props)
			renderCount = renderCount + 1
		end

		local ConnectedSomeComponent = connect2(mapStateToProps)(SomeComponent)

		local store = Rodux.Store.new(reducer)
		local tree = Roact.createElement(StoreProvider, {
			store = store,
		}, {
			someComponent = Roact.createElement(ConnectedSomeComponent),
		})

		local handle = Roact.reify(tree)

		expect(renderCount).to.equal(1)

		store:dispatch({ type = "an unknown action" })
		store:flush()

		expect(renderCount).to.equal(1)

		store:dispatch({ type = "increment" })
		store:flush()

		expect(renderCount).to.equal(2)

		Roact.teardown(handle)
	end)

	it("should only call mapDispatchToProps once and never re-render if no mapStateToProps was passed", function()
		local dispatchCount = 0
		local mapDispatchToProps = function(dispatch)
			dispatchCount = dispatchCount + 1

			return {
				increment = function()
					return dispatch({ type = "increment" })
				end,
			}
		end

		local renderCount = 0
		local function SomeComponent(props)
			renderCount = renderCount + 1
		end

		local ConnectedSomeComponent = connect2(nil, mapDispatchToProps)(SomeComponent)

		local store = Rodux.Store.new(reducer)
		local tree = Roact.createElement(StoreProvider, {
			store = store,
		}, {
			someComponent = Roact.createElement(ConnectedSomeComponent),
		})

		local handle = Roact.reify(tree)

		expect(dispatchCount).to.equal(1)
		expect(renderCount).to.equal(1)

		store:dispatch({ type = "an unknown action" })
		store:flush()

		expect(dispatchCount).to.equal(1)
		expect(renderCount).to.equal(1)

		store:dispatch({ type = "increment" })
		store:flush()

		expect(dispatchCount).to.equal(1)
		expect(renderCount).to.equal(1)

		Roact.teardown(handle)
	end)

	it("should return result values from the dispatch passed to mapDispatchToProps", function()
		local function reducer()
			return 0
		end

		local function fiveThunk()
			return 5
		end

		local dispatch
		local function SomeComponent(props)
			dispatch = props.dispatch
		end

		local function mapDispatchToProps(dispatch)
			return {
				dispatch = dispatch
			}
		end

		local ConnectedSomeComponent = connect2(nil, mapDispatchToProps)(SomeComponent)

		-- We'll use the thunk middleware, as it should always return its result
		local store = Rodux.Store.new(reducer, nil, { Rodux.thunkMiddleware })
		local tree = Roact.createElement(StoreProvider, {
			store = store,
		}, {
			someComponent = Roact.createElement(ConnectedSomeComponent)
		})

		local handle = Roact.reify(tree)

		expect(dispatch).to.be.a("function")
		expect(dispatch(fiveThunk)).to.equal(5)

		Roact.teardown(handle)
	end)
end