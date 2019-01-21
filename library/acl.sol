pragma solidity ^0.4.25;

/// @title This is the base contract to support ACL in flow contracts
///  Permission control is applied at function level, to the end it is "whether an address can call a function in a contract"
///  This ACL contract provides 3 ways for inheriting contracts to configure access control on the function
///   - directly configure addresses, which is exposed by modifier authAddresses()
///     once configured, the function can only be called by the addresses set in the modifier
///   - configure roles, which is exposed by modifier authRoles()
///     once configured, the function can only be called by the addresses which are assigned with the roles set in the modifier
///     permission manager can configure the (address -> role) mapping by calling configureAddressRole() through transaction after the contract is deployed
///   - configure functionHash, which is exposed by the modifier authFunctionHash()
///     we need to define a unique functionHash for a given function, and
///     once configured, the function can only be called by the addresses which are mapped to this functionHash
///     or the addresses which are assigned with the roles which are mapped to this functionHash
///     permission manager can configure the (functionHash -> address) mapping by calling configureFunctionAddress() through transaction after the contract is deployed
///     he can also configure the (functionHash -> role) mapping by calling configureFunctionRole() though transaction after the contract is deployed
contract ACL {
    /// operation mode
    /// add or remove a mapping
    enum OpMode { Add, Remove }
    
    struct Roles {
        bool exist;
        bytes32[] value; 
    }
    
    struct Addresses {
        bool exist;
        address[] value;
    }
    
    /// functionHash -> roles
    mapping (bytes32 => Roles) functionRolesMap; 
    /// address -> roles
    mapping (address => Roles) addressRolesMap;
    /// functionHash -> addresses
    mapping (bytes32 => Addresses) functionAddressesMap;
    
    /// @dev function to configure (functionHash -> roles) mapping
    ///  Note that this function itself is guarded by the authFunctionHash() modifier with a unique functionHash
    ///  and this design is applied to all configure functions in this ACL contract 
    /// @param _function functionHash to configure
    /// @param _role role to configure
    /// @param _opMode either add or remove
    string constant CONFIGURE_NORMAL_FUNCTION = "CONFIGURE_NORMAL_FUNCTION";
    function configureFunctionRole(string _function, string _role, OpMode _opMode) authFunctionHash(CONFIGURE_NORMAL_FUNCTION) public { 
        bytes32 func = keccak256(abi.encodePacked(_function));
        require(func != keccak256(abi.encodePacked(CONFIGURE_NORMAL_FUNCTION)), "not allowed");
        require(func != keccak256(abi.encodePacked(CONFIGURE_ADVANCED_FUNCTION)), "not allowed");
        require(func != keccak256(abi.encodePacked(CONFIGURE_SUPER_FUNCTION)), "not allowed");
        configureFunctionRoleInternal(_function, _role, _opMode);
    }

    string constant CONFIGURE_ADVANCED_FUNCTION = "CONFIGURE_ADVANCED_FUNCTION";
    function configureFunctionRoleAdvanced(string _role, OpMode _opMode) authFunctionHash(CONFIGURE_ADVANCED_FUNCTION) public {
        configureFunctionRoleInternal(CONFIGURE_NORMAL_FUNCTION, _role, _opMode);
    }

    string constant CONFIGURE_SUPER_FUNCTION = "CONFIGURE_SUPER_FUNCTION";
    function configureFunctionRoleSuper(string _role, OpMode _opMode) authFunctionHash(CONFIGURE_SUPER_FUNCTION) public {
        configureFunctionRoleInternal(CONFIGURE_ADVANCED_FUNCTION, _role, _opMode);
        configureFunctionRoleInternal(CONFIGURE_SUPER_FUNCTION, _role, _opMode);        
    }

    /// @dev internal function of configureFunctionRole()
    ///  internal configure functions are normally called in constructor of inheriting contracts
    function configureFunctionRoleInternal(string _functionStr, string _roleStr, OpMode _opMode) internal {
        bytes32 _role = keccak256(abi.encodePacked(_roleStr));
        bytes32 _function = keccak256(abi.encodePacked(_functionStr));
        Roles storage funcRole = functionRolesMap[_function];
        if (_opMode == OpMode.Add) {
            if (!funcRole.exist) {
                funcRole.exist = true;
                funcRole.value = new bytes32[](0);
                funcRole.value.push(_role);
                functionRolesMap[_function] = funcRole;
            } else {
                funcRole.value.push(_role);
            }
        } else if(_opMode == OpMode.Remove) {
            if (funcRole.exist) {
                for(uint i = 0; i < funcRole.value.length; i++) {
                    if (funcRole.value[i] == _role) {
                        /// @dev code review comments - jack
                        /// Use Swap & Delete mode when deleting an element in array
                        /// https://stackoverflow.com/questions/49051856/is-there-a-pop-functionality-for-solidity-arrays
                        /// This applies to all array deleting operations in this contract
                        delete funcRole.value[i];
                        break;
                    }
                }
            } 
        }
    }
    
    /// @dev function to configure (address -> roles) mapping
    /// @param _address address to configure
    /// @param _role role to configure
    /// @param _opMode either add or remove
    function configureAddressRole(address _address, string _role, OpMode _opMode) authFunctionHash(CONFIGURE_NORMAL_FUNCTION) public {
        configureAddressRoleInternal(_address, _role, _opMode);
    }

    /// @dev internal function of configureAddressRole()
    function configureAddressRoleInternal(address _address, string _roleStr, OpMode _opMode) internal {
        bytes32 _role = keccak256(abi.encodePacked(_roleStr));
        Roles storage addrRole = addressRolesMap[_address];
        if (_opMode == OpMode.Add) {
            if (!addrRole.exist) {
                addrRole.exist = true;
                addrRole.value = new bytes32[](0);
                addrRole.value.push(_role);
                addressRolesMap[_address] = addrRole;
            } else {
                addrRole.value.push(_role);
            }
        } else if(_opMode == OpMode.Remove) {
            if (addrRole.exist) {
                for(uint i = 0; i < addrRole.value.length; i++) {
                    if (addrRole.value[i] == _role) {
                        delete addrRole.value[i];
                        break;
                    }
                }
            } 
        }
    }
    
    /// @dev function to configure (functionHash -> addresses) mapping
    /// @param _function functionHash to configure
    /// @param _address address to configure
    /// @param _opMode either add or remove
    function configureFunctionAddress(string _function, address _address, OpMode _opMode) authFunctionHash(CONFIGURE_NORMAL_FUNCTION) public {
        bytes32 func = keccak256(abi.encodePacked(_function));
        require(func != keccak256(abi.encodePacked(CONFIGURE_NORMAL_FUNCTION)), "not allowed");
        require(func != keccak256(abi.encodePacked(CONFIGURE_ADVANCED_FUNCTION)), "not allowed");
        require(func != keccak256(abi.encodePacked(CONFIGURE_SUPER_FUNCTION)), "not allowed");
        configureFunctionAddressInternal(_function, _address, _opMode);
    }

    function configureFunctionAddressAdvanced(address _address, OpMode _opMode) authFunctionHash(CONFIGURE_ADVANCED_FUNCTION) public {
        configureFunctionAddressInternal(CONFIGURE_NORMAL_FUNCTION, _address, _opMode);
    }

    function configureFunctionAddressSuper(address _address, OpMode _opMode) authFunctionHash(CONFIGURE_SUPER_FUNCTION) public {
        configureFunctionAddressInternal(CONFIGURE_ADVANCED_FUNCTION, _address, _opMode);
        configureFunctionAddressInternal(CONFIGURE_SUPER_FUNCTION, _address, _opMode);
    }

    /// @dev internal function of configureFunctionAddress()
    function configureFunctionAddressInternal(string _functionStr, address _address, OpMode _opMode) internal {
        bytes32 _function = keccak256(abi.encodePacked(_functionStr));
        Addresses storage addrFunc = functionAddressesMap[_function];
        if (_opMode == OpMode.Add) {
              if (!addrFunc.exist) {
                addrFunc.exist = true;
                addrFunc.value = new address[](0);
                addrFunc.value.push(_address);
                functionAddressesMap[_function] = addrFunc;
            } else {
                addrFunc.value.push(_address);
            }
        } else if(_opMode == OpMode.Remove) {
             if (addrFunc.exist) {
                for(uint i = 0; i < addrFunc.value.length; i++) {
                    if (addrFunc.value[i] == _address) {
                        delete addrFunc.value[i];
                        break;
                    }
                }
            } 
        }
    }
    
    /// @dev only authorized addresses are allowed to call
    /// @param _addresses addresses in whitelist
    modifier authAddresses(address[] _addresses) {
        bool authorized =false;
        for(uint i = 0; i < _addresses.length; i++) {
            if (msg.sender == _addresses[i]) {
                authorized = true;
                break;
            }
        }
        
        require(authorized);
        _;
    }
    
    /// @dev only authorized roles are allowed to call
    /// @param _roles roles in whitelist
    modifier authRoles(string[] _roles) {
        Roles storage addrRoleMap = addressRolesMap[msg.sender];
        require(addrRoleMap.exist);
        
        bool authorized =false;
        for(uint i = 0; i < _roles.length; i++) {
            for(uint j = 0; j < addrRoleMap.value.length; j++) {
                if (keccak256(abi.encodePacked(_roles[i])) == addrRoleMap.value[j]) {
                    authorized = true;
                    break;
                }
            }
        }
        
        require(authorized);
        _;
    }
    
    /// @dev only addresses/roles configured with functionHash are allowed to call
    ///  internally it calls canPerform()
    /// @param _functionStr functioHash 
    modifier authFunctionHash(string _functionStr) {
        require(canPerform(msg.sender, _functionStr));
        _;
    }
    
    /// @dev check whether an address can call a function with specific functiohash
    ///  it first checks the (functionHash -> addresses) mapping
    ///  it then checks the (functionHash -> roles) and (address -> roles) mappings
    /// @param _caller the calling address
    /// @param _functionStr functioHash
    function canPerform(address _caller, string _functionStr) public view returns (bool) {
        bytes32 _function = keccak256(abi.encodePacked(_functionStr));
        /// check (functionHash -> addresses) mapping
        bool authorized = false;
        Addresses storage addrFuncMap = functionAddressesMap[_function];
        if (addrFuncMap.exist) {
            for(uint i = 0; i < addrFuncMap.value.length; i++) {
                if (addrFuncMap.value[i] == _caller) {
                   authorized = true;
                   break;
                }
            }
        }
        
        if (!authorized) {
            /// check (functionHash -> roles) mapping
            Roles storage funcRoleMap = functionRolesMap[_function];
            require(funcRoleMap.exist);
            
            /// check (address -> roles) mapping
            Roles storage addrRoleMap = addressRolesMap[_caller];
            require(addrRoleMap.exist);
            
            for(i = 0; i < funcRoleMap.value.length; i++) {
                for(uint j = 0; j < addrRoleMap.value.length; j++) {
                    if (funcRoleMap.value[i] == addrRoleMap.value[j]) {
                        authorized = true;
                        break;
                    }
                }
            }
        }
        
        return authorized;
    }
    
    /// @dev get roles assigned to an address
    /// @param _address the address to check
    function getAddressRolesMap(address _address) public view returns (bytes32[]) {
        bytes32[] memory result;
        Roles memory roles = addressRolesMap[_address];
        if (roles.exist) {
            result = new bytes32[](roles.value.length);
            for(uint i = 0; i < roles.value.length; i++) {
                 result[i] = roles.value[i];
            }
            return result;
        } else {
            return result;
        }
    }
}