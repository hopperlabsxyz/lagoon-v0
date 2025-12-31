

# make a clearer sentence for each combinaison
operators = ["safe"]
controllers = ["pfr", "user"]
gave_up_operator_privileges = ["Gave up. ", ""]

request_deposit = ["requestDeposit()", "requestDepositWithReferral()"]
request_redeem = ["requestRedeem()"]
deposit = ["deposit()"]
mint = ["mint()"]
redeem = ["redeem()"]
withdraw = ["withdraw()"]
functions = []
functions.extend(request_deposit)
functions.extend(request_redeem)
functions.extend(deposit)
functions.extend(mint)
functions.extend(redeem)
functions.extend(withdraw)

for controller in controllers:
    for gave_up_operator_privilege in gave_up_operator_privileges:
        for function in functions:
            if controller == "pfr" and gave_up_operator_privilege == "Gave up":
                continue
            result = "should succeed"
            if function in [request_deposit]:
                result = "should revert"
            if controller == "pfr":
                result = "should revert"
            if gave_up_operator_privilege == "gave up privileges":
                result = "should revert"
            print(f"// [] {function} for {controller}. {gave_up_operator_privilege}{result}")