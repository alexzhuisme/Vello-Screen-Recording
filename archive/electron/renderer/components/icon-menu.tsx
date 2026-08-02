import React, {FunctionComponent, useRef} from 'react';
import {SvgProps} from 'vectors/svg';

type MenuProps = {
  onOpen: (options: {x: number; y: number}) => void;
} | {
  template: any[];
  onSelect?: (value: any) => void;
};

type IconMenuProps = SvgProps & MenuProps & {
  icon: FunctionComponent<SvgProps>;
  fillParent?: boolean;
};

const IconMenu: FunctionComponent<IconMenuProps> = props => {
  const {icon: Icon, fillParent, ...iconProps} = props;
  const container = useRef(null);

  const openMenu = async () => {
    const boundingRect = container.current.children[0].getBoundingClientRect();
    const {bottom, left} = boundingRect;

    if ('onOpen' in props) {
      props.onOpen({
        x: Math.round(left),
        y: Math.round(bottom)
      });
    } else {
      const result = await window.kap.menu.popup(props.template, {
        x: Math.round(left),
        y: Math.round(bottom)
      });

      if (result !== null && 'onSelect' in props && props.onSelect) {
        props.onSelect(result);
      }
    }
  };

  return (
    <div ref={container} onClick={openMenu}>
      <Icon {...iconProps}/>
      <style jsx>{`
          display: flex;
          align-items: center;
          justify-content: center;
          width: ${fillParent ? '100%' : 'none'};
          height: ${fillParent ? '100%' : 'none'}
        `}</style>
    </div>
  );
};

export default IconMenu;
