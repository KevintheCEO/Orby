'use strict';
(() => {
 const media=matchMedia('(prefers-color-scheme: dark)'),reduce=matchMedia('(prefers-reduced-motion: reduce)');
 let mode='system',quiet=false;
 try {mode=localStorage.getItem('orby.appearance.v1')||'system';quiet=localStorage.getItem('orby.motion.v1')==='reduced';} catch {}
 if(!['system','dark','light'].includes(mode))mode='system';
 function apply(){document.documentElement.dataset.theme=mode==='system'?(media.matches?'dark':'light'):mode;document.documentElement.dataset.motion=quiet||reduce.matches?'reduced':'full';document.querySelector('meta[name="theme-color"]')?.setAttribute('content',document.documentElement.dataset.theme==='dark'?'#050506':'#eef0f5');window.dispatchEvent(new Event('orbyappearance'));}
 window.OrbyAppearance={get mode(){return mode;},get quiet(){return quiet;},get reduced(){return quiet||reduce.matches;},setMode(value){if(!['system','dark','light'].includes(value))return;mode=value;try{localStorage.setItem('orby.appearance.v1',mode);}catch{}apply();},setQuiet(value){quiet=!!value;try{localStorage.setItem('orby.motion.v1',quiet?'reduced':'full');}catch{}apply();}};
 media.addEventListener('change',apply);reduce.addEventListener('change',apply);apply();
})();
