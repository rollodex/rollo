var State = {
  user: { value: "", watchers: [] },  //web3.eth.addresses[0]
  id: { value: 0, watchers: [] }, //metamask change
  daiBal: { value: 0, watchers: [] }, //erc20 dai. getBalance
  btcBal: { value: 0, watchers: [] }, //erc20 wbtc. getBalance
  ethBal: { value: 0, watchers: [] },  //--------_____________---------
  created: { value: [], watchers: [] }, // - Iterate over factory
  path: {value: '', watchers: []},
  target: {value: '', watchers:[]},
  targetType: {value:0, watchers:[]},
  supplyTarget: {value:'', watchers:[]},
  repayTarget: {value:'', watchers:[]}
};

//-----Can get rate via API
var ethToDai = 177;
var btcToDai = 7444;

var maxUINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935';

var WC = {
 dai: {mainnet:"",rinkeby:"0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa",instance:undefined},
 btc: {mainnet:"",rinkeby:"0x577D296678535e4903D59A4C929B718e1D575e0A",instance:undefined},
 factory: {mainnet:"",rinkeby:"0x9db977322869BB501Ee9614fa4dd3a7230F9ecb2",instance:undefined},
 cdai: {mainnet:"",rinkeby:"0x6D7F0754FFeb405d23C51CE938289d4835bE3b14",instance:undefined},
 ceth: {mainnet:"",rinkeby:"0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e",instance:undefined},
 cbtc: {mainnet:"",rinkeby:"0x0014F450B8Ae7708593F4A46F8fa6E5D50620F96",instance:undefined}
}

function On(key, watcher) {
  State[key].watchers.push(watcher);
}

function Transition(route) {
  if (location.hash == "")
    route = 'hq'
  console.log("Route: " + route)
  TransitionTable[route].updater();
  TransitionTable[route].loader();
}

function UpdateState(key, value) {
  if (State[key].value === value) return;
  if (!(State[key].value instanceof Array)) {
    console.log("Not array");
    State[key].value = value;
    for (w in State[key].watchers) {
      State[key].watchers[w](value);
    }
  } else {
      console.log("Array");
      State[key].value.push(value);
      for (w in State[key].watchers) {
        State[key].watchers[w](value);
      }

  }
}

var TransitionTable = {
  hq: {
    loader: function () {
      $("#current").html(document.getElementById("hq").innerHTML);
    },
    updater: function() {}
  },

  info: {
    loader: function () {

    },
    updater: function() {}
  }
}

$(window).on("hashchange", function() {
  let route = location.hash.slice(1);
  let subroute = route.split('/')
  route = subroute[0];
  path = subroute[1];
  UpdateState('path',path)
  console.log('path:' + path);
  if (route == "") Transition("hq");

  if (route == "modal1" || route == "modal2" || route == "!") return;

  Transition(route);
});

function roundEth(x) {
  return Number.parseFloat(x).toFixed(4);
}

window.addEventListener("load", async () => {
  doModal();
  doNav();
  if (window.ethereum) {
    await ethereum.enable();
    window.web3 = new Web3(ethereum);
  } else if (window.web3) {
    // Then backup the good old injected Web3, sometimes it's usefull:
    window.web3old = window.web3;
    // And replace the old injected version by the latest build of Web3.js version 1.0.0
    window.web3 = new Web3(window.web3.currentProvider);
  }

  startApp();
});

function startApp() {
  var netId = web3.eth.net.getId().then( (id) =>  {
      console.log("Network Id: " + id);
      if (id == 1 ) {
        //$('#network-alert').removeAttr("hidden");
      }
      State["id"].value = id;
      window.web3.eth.getAccounts((error, accounts) => {
       State.user.value = accounts[0];

       makeContract('dai',window.ercABI);
       makeContract('btc',window.ercABI);
       makeContract('factory',window.factoryABI);
       makeContract('cbtc',window.cTokenABI);
       makeContract('ceth',window.cTokenABI);
       makeContract('cdai',window.cTokenABI);

       loadContracts();
     })
   })

  On("created", function(v) {
    var initialPrincipal = (v[1]);
    var rolledAmount = (v[2]);
    var type = parseInt(v[3]);
    var typeString1 = '';
    var typeString2 = '';
    var total = v[4];

    switch (type) {
      //Short Eth
      case 0:
        typeString1="$";
        typeString2='Ξ'
        initialPrincipal = web3.utils.fromWei(initialPrincipal);
        rolledAmount = web3.utils.fromWei(rolledAmount);
        total = web3.utils.fromWei(total);
      break;

      //Long Eth
      case 1:
        typeString1='Ξ'
        typeString2="$";
        initialPrincipal = web3.utils.fromWei(initialPrincipal);
        rolledAmount = web3.utils.fromWei(rolledAmount);
        total = web3.utils.fromWei(total);
      break;

      //Short Btc
      case 2:
         typeString1="$";
         typeString2='₿';
         initialPrincipal = web3.utils.fromWei(initialPrincipal);
         rolledAmount = parseFloat(rolledAmount) / 1e8;
         total = web3.utils.fromWei(total);
      break;

      //Long Btc
      case 3:
         typeString1='₿';
         typeString2="$";
         initialPrincipal = parseFloat(initialPrincipal) / 1e8;
         rolledAmount = web3.utils.fromWei(rolledAmount)
         total = parseFloat(total) / 1e8;
      break;

    }

    $('#wallets').append('<div class="inline-block p-4 mr-8 border" onclick="showInfoModal(\'' +v[0]+  '\')"><div class=""><div class=""><h3>'+typeString1+total+'</h3></div></div><hr  class="" /><div class="uk-card-body">'+typeString2 + rolledAmount + '</div><hr  /><div class="">' +typeString1+ initialPrincipal +'</div></div>')
  })

  On('target', function (v) {
       matchingContract = State.created.value.find((ele) => {
        return ele[0] == v;
      })
      UpdateState('targetType',parseInt(matchingContract[3]));

      UpdateHud(v);
  })
}

function UpdateHud(address) {
  var tokenInstanceSupply;
  var tokenInstanceBorrow;

  switch (State.targetType.value) {
    case 0:
     tokenInstanceSupply = WC.cdai.instance;
     tokenInstanceBorrow = WC.ceth.instance;
    break;
    case 1:
     tokenInstanceSupply = WC.ceth.instance;
     tokenInstanceBorrow = WC.cdai.instance;
    break;
    case 2:
     tokenInstanceSupply = WC.cdai.instance;
     tokenInstanceBorrow = WC.cbtc.instance;
    break;
    case 3:
     tokenInstanceSupply = WC.cbtc.instance;
     tokenInstanceBorrow = WC.cdai.instance;
    break;
  }

  tokenInstanceSupply.methods.balanceOfUnderlying(address).call().then(function (result) {
    var total = result;
    tokenInstanceBorrow.methods.borrowBalanceCurrent(address).call().then(function (result) {
      var rolledAmount = result;

      switch (parseInt(State.targetType.value)) {
        //Short Eth
        case 0:
          typeString1="$";
          typeString2='Ξ'
          rolledAmount = web3.utils.fromWei(rolledAmount);
          total = web3.utils.fromWei(total);
        break;

        //Long Eth
        case 1:
          typeString1='Ξ'
          typeString2="$";
          rolledAmount = web3.utils.fromWei(rolledAmount);
          total = web3.utils.fromWei(total);
        break;

        //Short Btc
        case 2:
           typeString1="$";
           typeString2='₿';
           rolledAmount = parseFloat(rolledAmount) / 1e8;
           total = web3.utils.fromWei(total);
        break;

        //Long Btc
        case 3:
           typeString1='₿';
           typeString2="$";
           rolledAmount = web3.utils.fromWei(rolledAmount)
           total = parseFloat(total) / 1e8;
        break;

      }
      $('#target-sp').text(typeString1 + roundEth(total));
      $('#target-br').text(typeString2 + roundEth(rolledAmount));
    })
  })
}

function doNav() {
  if (location.hash == "") {
    Transition("hq");
  } else {
    console.log('hash: ' + location.hash)
    let route = location.hash.slice(1);
    let subroute = route.split('/');
    route = subroute[0];
    path = subroute[1];
    UpdateState('path',path)
    Transition(route)
  }
}

function makeContract(name,abi) {
  var id = State["id"].value;
  var network = ''

  switch (id) {
    case 1:
      network = 'mainnet';
      break;

    case 4:
      network = 'rinkeby';
      break;

  }

  var entry = WC[name];
  var address = entry[network];
  var instance = new web3.eth.Contract(abi,address);
  WC[name].instance = instance;

}

function loadContracts() {
  var factory = WC.factory.instance;

factory.methods.contractCount().call().then(function (count) {
 var loop = count - 1;

 while(loop >= 0) {
   factory.methods.contracts(loop).call().then(function (address) {
    addSingleContract(address);
   })
   loop--;
 }

})
}

function loadContractInfo(address) {

  return new web3.eth.Contract(window.parentABI, address);
}

function loadContract(address, type) {
  var contractABI;

   switch (type) {
     case 0:
       contractABI = window.shortEthABI;
     break;

     case 1:
       contractABI = window.longEthABI;
     break;

     case 2:
       contractABI = window.shortBtcABI;
     break;

     case 3:
       contractABI = window.longBtcABI;
     break;

   }

   return new web3.eth.Contract(contractABI, address);
}

function addSingleContract(address) {
  var walletContract = loadContractInfo(address);
  var walletAddress = address;
  walletContract.methods.offerType().call().then(function (result) {
    var type = result;
    var tokenInstanceSupply;
    var tokenInstanceBorrow;
    switch (parseInt(type)) {
      case 0:
       tokenInstanceSupply = WC.cdai.instance;
       tokenInstanceBorrow = WC.ceth.instance;
      break;
      case 1:
       tokenInstanceSupply = WC.ceth.instance;
       tokenInstanceBorrow = WC.cdai.instance;
      break;
      case 2:
       tokenInstanceSupply = WC.cdai.instance;
       tokenInstanceBorrow = WC.cbtc.instance;
      break;
      case 3:
       tokenInstanceSupply = WC.cbtc.instance;
       tokenInstanceBorrow = WC.cdai.instance;
      break;
    }

    walletContract.methods.initialPrincipal().call().then(function (result) {
      var initialPrincipal = result;
      tokenInstanceSupply.methods.balanceOfUnderlying(walletAddress).call().then(function (result) {
        var total = result;
        tokenInstanceBorrow.methods.borrowBalanceCurrent(walletAddress).call().then(function (result) {
          var rolledAmount = result;
          walletContract.methods.creator().call().then(function (result) {
            var creator = result;

            if (creator == State.user.value) {
               var contractStats = [walletAddress,initialPrincipal,rolledAmount,type,total];
               UpdateState("created",contractStats);
            }
          })
        })
      })
    })
  })
}

function showWalletModal() {
  $("#modal-content").html(document.getElementById('createModal').innerHTML);
  toggleModal();
}

function showInfoModal(address) {

  $("#modal-content").html('<div class="flex justify-between items-center pb-3"> <p class="text-2xl font-bold">Wallet Info </p> </div> <div class="flex mb-4"> <div class="w-1/2 border h-12"><p class="text-xl font-bold ml-3 mt-2">Supplying: <span class="ml-3 mt-2 font-thin" id="target-sp"></span</p>></div> <div class="w-1/2 border h-12"><p class="text-xl font-bold ml-3 mt-2">Borrowing:<span class="ml-3 mt-2 font-thin" id="target-br"></span></p></div> </div> <div class="flex mb-4"> <div class="w-1/3 border "> <div><center>Supply</center></div> <div> <form> <input id="supplyAmt" autocomplete="off" class="appearance-none block w-full bg-gray-200 text-gray-700 border border-red-500 rounded py-3 px-4 mt-4 mb-3 leading-tight focus:outline-none focus:bg-white"></input> <center><button type="button" onclick="doSupply()" class="bg-gray-300 hover:bg-gray-400 text-gray-800 font-bold py-2 px-4 m-8 rounded inline-flex items-center">Supply</button></center> </form> </div> </div> <div class="w-1/3 border "> <div><center>Widthdraw</center></div> <div> <form> <input id="wdAmt" class="appearance-none block w-full bg-gray-200 text-gray-700 border border-red-500 rounded py-3 px-4 mt-4 mb-3 leading-tight focus:outline-none focus:bg-white"></input> <center><button type="button" onclick="doWD()" class="bg-gray-300 hover:bg-gray-400 text-gray-800 font-bold py-2 px-4 m-8 rounded inline-flex items-center">Widthdraw</button></center> </form> </div> </div> <div class="w-1/3 border "> <div><center>Repay</center></div> <div> <form> <input id="repayAmt" class="appearance-none block w-full bg-gray-200 text-gray-700 border border-red-500 rounded py-3 px-4 mt-4 mb-3 leading-tight focus:outline-none focus:bg-white"></input> <center><button type="button" onclick="doRepay()" class="bg-gray-300 hover:bg-gray-400 text-gray-800 font-bold py-2 px-4 m-8 rounded inline-flex items-center">Repay</button></center> </form> </div> </div> </div> <div class="flex mb-4"> <div class="w-full h-12"><center><button type="button" onclick="doRoll()" class="bg-gray-300 hover:bg-gray-400 text-gray-800 font-bold py-2 px-4 rounded inline-flex items-center">Roll</button></center></div> </div>');
  UpdateState('target',address);
  toggleModal();
}

function toggleModal () {

      const body = document.querySelector('body')
      const modal = document.querySelector('.modal')
      modal.classList.toggle('opacity-0')
      modal.classList.toggle('pointer-events-none')
      body.classList.toggle('modal-active')
}

 function doModal() {
   var openmodal = document.querySelectorAll('.modal-open')
    for (var i = 0; i < openmodal.length; i++) {
      openmodal[i].addEventListener('click', function(event){
    	event.preventDefault()
    	toggleModal()
      })
    }

    const overlay = document.querySelector('.modal-overlay')
    overlay.addEventListener('click', toggleModal)

    var closemodal = document.querySelectorAll('.modal-close')
    for (var i = 0; i < closemodal.length; i++) {
      closemodal[i].addEventListener('click', toggleModal)
    }

    document.onkeydown = function(evt) {
      evt = evt || window.event
      var isEscape = false
      if ("key" in evt) {
    	isEscape = (evt.key === "Escape" || evt.key === "Esc")
      } else {
    	isEscape = (evt.keyCode === 27)
      }
      if (isEscape && document.body.classList.contains('modal-active')) {
    	toggleModal()
      }
    };
 }

async function createContract(type) {
   var factory = WC.factory.instance;
   var methodToCall;
   var tokenToApprove;
   var bigNum = web3.utils.toBN(maxUINT);

   switch (type) {
     //Short Eth
     case 0:
       methodToCall = factory.methods.createShortETHContract;
       tokenToApprove = WC.dai.instance;
     break;

     //Long Eth
     case 1:
      methodToCall = factory.methods.createLongETHContract;
      tokenToApprove = undefined;
     break;

     //Short Btc
     case 2:
      methodToCall = factory.methods.createShortBTCContract;
      tokenToApprove = WC.dai.instance;
     break;

     //Long Btc
     case 3:
      methodToCall = factory.methods.createLongBTCContract;
      tokenToApprove = WC.btc.instance;
     break;

   }
   try {
      const hash = await methodToCall().send({
        from: State.user.value,
      }).then (function (result) {
         var walletAddress = result.events.ContractCreated.returnValues._contractwallet;
         addSingleContract(walletAddress);
         if (tokenToApprove == undefined)
           return;
        try {
            tokenToApprove.methods.approve(walletAddress,bigNum).send({
            from: State.user.value,
          }).then (function (result) {

          });

        } catch (e) {
          // if user cancel transaction at Metamask UI we'll get error and handle it here
          console.log(e);
          alert("Rejected in MetaMask.");
        }

      });
    } catch (e) {
      // if user cancel transaction at Metamask UI we'll get error and handle it here
      console.log(e);
      alert("Rejected in MetaMask.");
    }
}

function doSupply() {
    var theContract = loadContract(State.target.value,State.targetType.value);
    var supplyValue = $('#supplyAmt').val();

    switch (State.targetType.value) {
      case 0:
        var supplyAmt = web3.utils.toWei(supplyValue);
        theContract.methods.initialDepositDai(supplyAmt).send({
        from: State.user.value
      }).then(function (result) {
        UpdateHud(State.target.value)});
      break;

      case 1:
      var supplyAmt = web3.utils.toWei(supplyValue);
      theContract.methods.initialDepositETH().send({
      from: State.user.value,
      value:supplyAmt
    }).then(function (result) {
      UpdateHud(State.target.value)});
      break;

      case 2:
      var supplyAmt = web3.utils.toWei(supplyValue);
      theContract.methods.initialDepositDai(supplyAmt).send({
      from: State.user.value
    }).then(function (result) {
      UpdateHud(State.target.value)});
      break;

      case 3:
      var supplyAmt = parseInt(supplyValue * 1e8);
      theContract.methods.initialDepositBTC(supplyAmt).send({
      from: State.user.value
    }).then(function (result) {
      UpdateHud(State.target.value)});
      break;

    }
}

function doWD() {
  var theContract = loadContract(State.target.value,State.targetType.value);
  var wdValue = $('#wdAmt').val();
  var wdAmt;
    switch (State.targetType.value) {
      case 0:
      case 1:
      case 2:
       wdAmt = web3.utils.toWei(wdValue);
      break;

      case 3:
       wdAmt = parseInt(wdValue * 1e8);
      break;
    }

    theContract.methods.widthdrawal(wdValue).send({
    from: State.user.value
   }).then(function (result) {
     UpdateHud(State.target.value);
   });

}

function doRepay() {
   var repayEth = false;
   var theContract = loadContract(State.target.value,State.targetType.value);
   var rpValue = $('#repayAmt').val();
   var rpAmt;
   switch (State.targetType.value) {
     case 0:
        repayEth = true;
     case 1:
        wdAmt = parseInt(wdValue) * 1e8;
       break;
     case 2:
      rpAmt = parseInt(wdValue) * 1e8;
     break;

     case 3:
      wdAmt = parseInt(wdValue) * 1e8;
     break;
   }

   if (repayEth == true) {
     theContract.methods.repay().send({
     from: State.user.value,
     value: rpAmt
    }).then(function (result) {
      UpdateHud(State.target.value);
    });
   } else {
     theContract.methods.repay(rpAmt).send({
     from: State.user.value
    }).then(function (result) {
      UpdateHud(State.target.value);
    });
   }
}

function doRoll() {
    var theContract = loadContract(State.target.value,State.targetType.value);
    theContract.methods.rollToSupply().send({from: State.user.value}).then(function (result) {
      UpdateHud(State.target.value);
    });
}
