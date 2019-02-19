import * as React from 'react';
import { Omit } from '@material-ui/core';

import { getParam } from '../api';
import Autocomplete, { AutocompleteProps, AutocompleteOption } from './Autocomplete';

interface PathFieldProps extends Omit<AutocompleteProps, 'loadOptions'> {
	symlink?: 'resolve' | 'follow';
}

export default class PathField extends React.Component<PathFieldProps> {

	cache: { [K: string]: AutocompleteOption[] } = {};

	loadOptions = async (value: string) => {
		const prefix = value.replace(/\/[^\/]*$/, '');
		value = prefix === '' ? '/' : prefix;
		const cached = this.cache[value];
		if (cached !== undefined) {
			return cached;
		}
		const parent = await getParam(value, this.props.symlink);
		if (parent.children === undefined) {
			this.cache[value] = [];
			return [];
		}
		const options = parent.children.map(child => ({ label: child.name, value: prefix + '/' + child.name }));
		this.cache[value] = options;
		return options;
	}

	loadFilteredOptions = async (value: string) => {
		return (await this.loadOptions(value))
			.filter(option => option.value.startsWith(value));
	}

	render() {
		const { symlink, ...props } = this.props;
		return <Autocomplete {...props} loadOptions={this.loadFilteredOptions}/>;
	}

}