function ephtosp3(varargin)
%-------------------------------------------------------------------------------
% [system] : GpsTools
% [module] : convert ephemeris estimation to sp3 format
% [func]   : convert ephemeris estimation to sp3 format
% [argin]  : (opts) = options
%                'td',td     : date (mjd)
%                'span',span : time span (days)    (default:1)
%                'tint',tint : time interval (sec) (default:900)
%                'sats',sats : satellite list      (default:all)
%                'file',file : file name           (default:'ephs')
%                'idir',idir : input estimation directory
%                'odir',odir : output products directory
%                'vel'       : contain satellite velocity estimation
%                'leo'       : leo satellite orbit/clock
%                'fb',fb     : use forward/backward estimation
%                              ('f':forward,'b':backward,'fb':smoothed)
%                'cbmsg',cbmsg : progress message callback
% [argout] : none
% [note]   :
% [version]: $Revision: 16 $ $Date: 2008-12-12 15:49:30 +0900 (金, 12 12 2008) $
%            Copyright(c) 2004-2008 by T.Takasu, all rights reserved
% [history]: 04/11/17  0.1  new
%            05/01/03  0.2  support estimated erp
%            05/06/28  0.3  add option fb, delete option back
%            05/08/15  0.4  add leo satellite pos/clk option
%            08/12/11  0.5  read ephemeris/clock by readeph/readclk
%                           support progress message callback
%-------------------------------------------------------------------------------
prm=loadprm('prm_gpsest');
[td,ts]=caltomjd(prm.tstart); span=1; tint=900; sats=prm.sats; fname='ephs';
idir=''; odir=''; pv='P'; leo=0; fb='fb'; agency=''; comment=''; n=1; cbmsg='';
while n<=length(varargin)
    switch varargin{n}
    case 'td',    td    =varargin{n+1}; n=n+2;
    case 'span',  span  =varargin{n+1}; n=n+2;
    case 'tint',  tint  =varargin{n+1}; n=n+2;
    case 'sats',  sats  =varargin{n+1}; n=n+2;
    case 'file',  fname =varargin{n+1}; n=n+2;
    case 'idir',  idir  =varargin{n+1}; n=n+2;
    case 'odir',  odir  =varargin{n+1}; n=n+2;
    case 'agency',  agency =varargin{n+1}; n=n+2;
    case 'comment', comment=varargin{n+1}; n=n+2;
    case 'fb',    fb    =varargin{n+1}; n=n+2;
    case 'vel',   pv='V'; n=n+1;
    case 'leo',   leo=1; n=n+1;
    case 'cbmsg', cbmsg=varargin{n+1}; n=n+2;
    otherwise, n=n+1; end
end
if ischar(sats), sats={sats}; end

for td=td:td+span-1
    time=0:tint:86400-tint;
    if ~leo
        [ephs,clks,refc]=ReadEphClk(td,time,sats,idir,fb,prm.tunit);
    else
        [ephs,clks,refc]=ReadPosClk(td,time,sats,idir,fb,prm.tunit);
    end
    dv=mjdtocal(td,time(1)); 
    msg=sprintf('%04d/%02d/%02d %02d:%02d',dv(1:5)); 
    
    if ~isempty(ephs)
        if outmsg(cbmsg,['generating sp3: ',msg]), return; end
        
        gpsd=td-44244; gpsw=floor(gpsd/7);
        file=sprintf('%s%04d%1d.sp3',fname,gpsw,floor(gpsd-gpsw*7));
        file=gfilepath(odir,file,dv,'',1);
        f=fopen(file,'wt');
        if f>0
            WriteHeader(f,td,time,sats,gpsw,gpsd,pv,refc,agency,comment,leo);
            WriteBody(f,td,time,sats,ephs,clks,pv,leo);
            fclose(f);
        end
    else
        if outmsg(cbmsg,['no ephemerisi data: ',msg]), return; end
    end
end
if ~isempty(cbmsg), feval(cbmsg{:},'done'); end

% write sp3 header -------------------------------------------------------------
function WriteHeader(f,td,time,sats,gpsw,gpsd,pv,refc,agency,comment,leo)

fprintf(f,'#a%c%04d %2d %2d %2d %2d %11.8f %7d %5s %4s %3s %4s\n',...
        pv,mjdtocal(td,0),length(time),'U','IGS00','FIT',agency);
fprintf(f,'## %4d %15.8f %14.8f %5d %15.13f\n',gpsw,(gpsd-gpsw*7)*86400,...
        time(2)-time(1),td,0);
n=0; ns=length(sats);
for m=1:5
    if m==1, fprintf(f,'+   %2d   ',ns); else fprintf(f,'+        '); end
    for k=1:17
        n=n+1;
        if n>ns, fprintf(f,'%3d',0);
        elseif ~leo
            fprintf(f,'G%02d',sscanf(sats{n},'GPS%d'));
        else
            fprintf(f,'L%02d',n);
        end
    end
    fprintf(f,'\n');
end
for n=1:5
    fprintf(f,'++       '); for m=1:17, fprintf(f,'%3d',0); end, fprintf(f,'\n');
end
comment2='';
if leo
    for n=1:length(sats)
        comment2=[comment2,sprintf('L%02d=%s ',n,sats{n})];
    end
end
fprintf(f,'%%c cc cc ccc ccc cccc cccc cccc cccc ccccc ccccc ccccc ccccc\n');
fprintf(f,'%%c cc cc ccc ccc cccc cccc cccc cccc ccccc ccccc ccccc ccccc\n');
fprintf(f,'%%f  0.0000000  0.000000000  0.00000000000  0.000000000000000\n');
fprintf(f,'%%f  0.0000000  0.000000000  0.00000000000  0.000000000000000\n');
fprintf(f,'%%i    0    0    0    0      0      0      0      0         0\n');
fprintf(f,'%%i    0    0    0    0      0      0      0      0         0\n');
fprintf(f,'/* %-57s\n',['GENERATED BY GPSTOOLS, REFERENCE CLOCK : ',refc]);
fprintf(f,'/* %-57.57s\n',comment);
fprintf(f,'/* %-57.57s\n',comment2);
fprintf(f,'/* %-57.57s\n','');

% write sp3 body ---------------------------------------------------------------
function WriteBody(f,td,time,sats,ephs,clks,pv,leo)
C=299792458; nanv=999999.999999;
for n=1:length(time)
    fprintf(f,'*  %04d %2d %2d %2d %2d %11.8f\n',mjdtocal(td,time(n)));
    for m=1:length(sats)
        if ~leo
           s='G'; no=sscanf(sats{m},'GPS%d');
        else
           s='L'; no=m;
        end
        pos=ephs(n,1:3,m)/1E3;  if isnan(pos(1)), pos=repmat(nanv,1,3); end
        vel=ephs(n,4:6,m)*1E1;  if isnan(vel(1)), vel=repmat(nanv,1,3); end
        clk=clks(n,1,m)*1E6;    if isnan(clk), clk=nanv; end
        cdf=clks(n,2,m)*1E10;   if isnan(cdf), cdf=nanv; end
        fprintf(f,'P%c%02d %13.6f %13.6f %13.6f %13.6f\n',s,no,pos,clk);
        if pv=='V'
            fprintf(f,'V%c%02d %13.6f %13.6f %13.6f %13.6f\n',s,no,vel,cdf);
        end
    end
end
fprintf(f,'EOF\n');

% read estimated ephemeris and clock (ecef) ------------------------------------
function [ephs,clks,refc]=ReadEphClk(td,time,sats,idir,fb,tunit)
clks=zeros(length(time),2,length(sats));
[ephs,sigs]=readeph(td,time,sats,idir,['eph',fb],tunit);
[clks(:,1,:),sigs,refc]=readclk(td,time,sats,idir,['clk',fb],tunit);

% read estimated leo position and clock (ecef) ---------------------------------
function [ephs,clks,refc]=ReadPosClk(td,time,sats,idir,fb,tunit)
clks=zeros(length(time),2,length(sats));
[ephs,sigs]=readpos(td,time,sats,idir,['pos',fb],tunit);
[clks(:,1,:),sigs]=readclk(td,time,sats,idir,['clk',fb],tunit);
refc='';

% output message ---------------------------------------------------------------
function abort=outmsg(cbmsg,msg)
if isempty(cbmsg)
    disp(msg); abort=0;
else
    abort=feval(cbmsg{:},msg);
    if abort, feval(cbmsg{:},'aborted'); end
end
